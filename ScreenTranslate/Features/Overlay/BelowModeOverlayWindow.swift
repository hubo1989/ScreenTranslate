import AppKit
import CoreGraphics
import SwiftUI

// MARK: - CGFloat Extension

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - BelowModeOverlayDelegate

/// Delegate protocol for below mode overlay events.
@MainActor
protocol BelowModeOverlayDelegate: AnyObject {
    /// Called when user dismisses the overlay.
    func belowModeOverlayDidDismiss()
}

// MARK: - BelowModeOverlayWindow

/// NSPanel subclass for displaying translated text below original text.
/// Implements "below original" mode: shows translation below each text block.
final class BelowModeOverlayWindow: NSPanel {
    // MARK: - Properties

    /// The screen this overlay covers
    let targetScreen: NSScreen

    /// The display info for this screen
    let displayInfo: DisplayInfo

    /// OCR results for text positioning
    private let ocrResults: [OCRText]

    /// Translation results mapping to OCR texts
    private let translations: [TranslationResult]

    /// The captured screenshot for background color sampling
    private let capturedImage: CGImage?

    /// The content view handling drawing and interaction
    private var overlayView: BelowModeOverlayView?

    /// Delegate for overlay events
    weak var overlayDelegate: BelowModeOverlayDelegate?

    // MARK: - Initialization

    /// Creates a new below mode overlay window.
    /// - Parameters:
    ///   - screen: The NSScreen to overlay
    ///   - displayInfo: The DisplayInfo for the screen
    ///   - ocrResults: OCR text observations with bounding boxes
    ///   - translations: Translation results for each OCR text
    ///   - capturedImage: Optional screenshot for background sampling
    @MainActor
    init(
        screen: NSScreen,
        displayInfo: DisplayInfo,
        ocrResults: [OCRText],
        translations: [TranslationResult],
        capturedImage: CGImage? = nil
    ) {
        self.targetScreen = screen
        self.displayInfo = displayInfo
        self.ocrResults = ocrResults
        self.translations = translations
        self.capturedImage = capturedImage

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupOverlayView()
    }

    // MARK: - Configuration

    @MainActor
    private func configureWindow() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
    }

    @MainActor
    private func setupOverlayView() {
        let view = BelowModeOverlayView(
            frame: targetScreen.frame,
            ocrResults: ocrResults,
            translations: translations,
            displayInfo: displayInfo,
            capturedImage: capturedImage,
            window: self
        )
        view.autoresizingMask = [.width, .height]
        self.contentView = view
        self.overlayView = view
    }

    // MARK: - Public API

    /// Shows the overlay window
    @MainActor
    func showOverlay() {
        makeKeyAndOrderFront(nil)
    }

    /// Hides and closes the overlay window
    @MainActor
    func hideOverlay() {
        orderOut(nil)
        close()
    }

    // MARK: - NSWindow Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            overlayDelegate?.belowModeOverlayDidDismiss()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - BelowModeOverlayView

/// Custom NSView for drawing translations below original text.
/// Shows translated text below each OCR text block with distinctive styling.
final class BelowModeOverlayView: NSView {
    // MARK: - Properties

    private let ocrResults: [OCRText]
    private let translations: [TranslationResult]
    private let displayInfo: DisplayInfo
    private let capturedImage: CGImage?
    private weak var windowRef: BelowModeOverlayWindow?
    private var trackingArea: NSTrackingArea?

    // MARK: - Styling Constants

    /// Vertical spacing between original text and translation
    private let translationSpacing: CGFloat = 4

    /// Horizontal padding for translation background
    private let horizontalPadding: CGFloat = 8

    /// Vertical padding for translation background
    private let verticalPadding: CGFloat = 4

    /// Corner radius for translation background
    private let backgroundCornerRadius: CGFloat = 6

    /// Translation background color (semi-transparent dark)
    private var translationBackgroundColor: NSColor {
        NSColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 0.85)
    }

    /// Translation text color
    private var translationTextColor: NSColor {
        NSColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
    }

    // MARK: - Initialization

    init(
        frame frameRect: NSRect,
        ocrResults: [OCRText],
        translations: [TranslationResult],
        displayInfo: DisplayInfo,
        capturedImage: CGImage?,
        window: BelowModeOverlayWindow
    ) {
        self.ocrResults = ocrResults
        self.translations = translations
        self.displayInfo = displayInfo
        self.capturedImage = capturedImage
        self.windowRef = window
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [
            .activeAlways,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]

        let area = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        setupTrackingArea()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        for (index, ocrText) in ocrResults.enumerated() {
            guard index < translations.count else { break }

            let translation = translations[index]
            drawTranslationBelow(translation, for: ocrText, context: context)
        }
    }

    private func drawTranslationBelow(
        _ translation: TranslationResult,
        for ocrText: OCRText,
        context: CGContext
    ) {
        let originalRect = convertToScreenCoordinates(ocrText.boundingBox)
        guard originalRect.intersects(bounds) else { return }

        // Determine text alignment based on original text position
        let textAlignment = determineAlignment(for: originalRect)

        // Calculate font size based on original text height
        let fontSize = calculateFontSize(for: originalRect)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)

        // Create paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Text attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: translationTextColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(
            string: translation.translatedText,
            attributes: attributes
        )

        // Calculate text size with max width (allowing extension to the right)
        let maxWidth = max(originalRect.width, bounds.width - originalRect.minX - 20)
        let textSize = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        // Calculate translation position (below original text)
        let translationWidth = textSize.width + horizontalPadding * 2
        let translationHeight = textSize.height + verticalPadding * 2

        // Position translation below original, aligned with it
        let translationX = calculateTranslationX(
            originalRect: originalRect,
            translationWidth: translationWidth,
            alignment: textAlignment
        )
        let translationY = originalRect.minY - translationSpacing - translationHeight

        // Clamp to screen bounds (extend down if needed)
        let clampedY = max(10, translationY)
        let clampedX = max(10, min(translationX, bounds.width - translationWidth - 10))

        let backgroundRect = CGRect(
            x: clampedX,
            y: clampedY,
            width: translationWidth,
            height: translationHeight
        )

        // Draw background with rounded corners
        let backgroundPath = CGPath(
            roundedRect: backgroundRect,
            cornerWidth: backgroundCornerRadius,
            cornerHeight: backgroundCornerRadius,
            transform: nil
        )

        context.saveGState()

        // Draw semi-transparent background
        context.setFillColor(translationBackgroundColor.cgColor)
        context.addPath(backgroundPath)
        context.fillPath()

        // Draw subtle border for better visibility
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(0.5)
        context.addPath(backgroundPath)
        context.strokePath()

        context.restoreGState()

        // Draw text
        let textRect = CGRect(
            x: backgroundRect.origin.x + horizontalPadding,
            y: backgroundRect.origin.y + verticalPadding,
            width: backgroundRect.width - horizontalPadding * 2,
            height: backgroundRect.height - verticalPadding * 2
        )
        attributedString.draw(in: textRect)
    }

    /// Determines text alignment based on the position of original text
    private func determineAlignment(for rect: CGRect) -> NSTextAlignment {
        let centerThreshold: CGFloat = 0.1 // 10% tolerance for center detection

        let rectCenterX = rect.midX
        let screenCenterX = bounds.midX

        let normalizedOffset = abs(rectCenterX - screenCenterX) / bounds.width

        // If the text is close to the center of the screen, use center alignment
        if normalizedOffset < centerThreshold {
            return .center
        }

        // Otherwise, use left alignment (most common for paragraphs)
        return .left
    }

    /// Calculates X position for translation based on alignment
    private func calculateTranslationX(
        originalRect: CGRect,
        translationWidth: CGFloat,
        alignment: NSTextAlignment
    ) -> CGFloat {
        switch alignment {
        case .center:
            // Center translation under original text
            return originalRect.midX - translationWidth / 2
        case .right:
            // Right-align translation with original text
            return originalRect.maxX - translationWidth
        default:
            // Left-align translation with original text
            return originalRect.minX
        }
    }

    private func convertToScreenCoordinates(_ normalizedBox: CGRect) -> CGRect {
        CGRect(
            x: normalizedBox.minX * bounds.width,
            y: normalizedBox.minY * bounds.height,
            width: normalizedBox.width * bounds.width,
            height: normalizedBox.height * bounds.height
        )
    }

    private func calculateFontSize(for rect: CGRect) -> CGFloat {
        let minFontSize: CGFloat = 10
        let maxFontSize: CGFloat = 28
        let calculatedSize = rect.height * 0.7
        return max(minFontSize, min(maxFontSize, calculatedSize))
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        var isOutside = true
        for ocrText in ocrResults {
            let screenRect = convertToScreenCoordinates(ocrText.boundingBox)
            // Expand the hit area to include the translation below
            let expandedRect = CGRect(
                x: screenRect.minX - 20,
                y: screenRect.minY - 60,  // Include translation area below
                width: max(screenRect.width + 40, 200),
                height: screenRect.height + 70
            )
            if expandedRect.contains(point) {
                isOutside = false
                break
            }
        }

        if isOutside {
            windowRef?.overlayDelegate?.belowModeOverlayDidDismiss()
        }
    }
}

// MARK: - BelowModeOverlayController

/// Controller for managing below mode overlay lifecycle.
@MainActor
final class BelowModeOverlayController {
    // MARK: - Properties

    /// Shared instance
    static let shared = BelowModeOverlayController()

    /// The current overlay window
    private var overlayWindow: BelowModeOverlayWindow?

    /// Delegate for overlay events
    weak var overlayDelegate: BelowModeOverlayDelegate?

    /// Callback for when overlay is dismissed
    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Presents below mode overlay with the given OCR and translation results.
    func presentOverlay(
        ocrResult: OCRResult,
        translations: [TranslationResult],
        capturedImage: CGImage? = nil
    ) {
        dismissOverlay()

        guard let screen = NSScreen.main else { return }

        let displayInfo = DisplayInfo(
            id: CGMainDisplayID(),
            name: screen.localizedName,
            frame: screen.frame,
            scaleFactor: screen.backingScaleFactor,
            isPrimary: true
        )

        let overlay = BelowModeOverlayWindow(
            screen: screen,
            displayInfo: displayInfo,
            ocrResults: ocrResult.observations,
            translations: translations,
            capturedImage: capturedImage
        )
        overlay.overlayDelegate = self

        self.overlayWindow = overlay
        overlay.showOverlay()
    }

    /// Dismisses the current overlay.
    func dismissOverlay() {
        overlayWindow?.hideOverlay()
        overlayWindow = nil
    }
}

// MARK: - BelowModeOverlayController + BelowModeOverlayDelegate

extension BelowModeOverlayController: BelowModeOverlayDelegate {
    func belowModeOverlayDidDismiss() {
        dismissOverlay()
        onDismiss?()
    }
}
