import AppKit
import CoreGraphics
import SwiftUI

// MARK: - TranslationOverlayDelegate

/// Delegate protocol for translation overlay events.
@MainActor
protocol TranslationOverlayDelegate: AnyObject {
    /// Called when user dismisses the overlay.
    func translationOverlayDidDismiss()
}

// MARK: - TranslationOverlayWindow

/// NSPanel subclass for displaying translated text overlay on screen.
/// Shows translated text at the exact position of original text using OCR bounding boxes.
final class TranslationOverlayWindow: NSPanel {
    // MARK: - Properties

    /// The screen this overlay covers
    let targetScreen: NSScreen

    /// The display info for this screen
    let displayInfo: DisplayInfo

    /// OCR results for text positioning
    private let ocrResults: [OCRText]

    /// Translation results mapping to OCR texts
    private let translations: [TranslationResult]

    /// The content view handling drawing and interaction
    private var overlayView: TranslationOverlayView?

    /// Delegate for overlay events (named to avoid conflict with NSWindow.delegate)
    weak var overlayDelegate: TranslationOverlayDelegate?

    // MARK: - Initialization

    /// Creates a new translation overlay window.
    /// - Parameters:
    ///   - screen: The NSScreen to overlay
    ///   - displayInfo: The DisplayInfo for the screen
    ///   - ocrResults: OCR text observations with bounding boxes
    ///   - translations: Translation results for each OCR text
    @MainActor
    init(
        screen: NSScreen,
        displayInfo: DisplayInfo,
        ocrResults: [OCRText],
        translations: [TranslationResult]
    ) {
        self.targetScreen = screen
        self.displayInfo = displayInfo
        self.ocrResults = ocrResults
        self.translations = translations

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
        // Window properties for full-screen overlay
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false

        // Don't hide on deactivation
        hidesOnDeactivate = false

        // Behavior
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false

        // Accept mouse events
        acceptsMouseMovedEvents = true
    }

    @MainActor
    private func setupOverlayView() {
        let view = TranslationOverlayView(
            frame: targetScreen.frame,
            ocrResults: ocrResults,
            translations: translations,
            displayInfo: displayInfo,
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
        // Escape key dismisses overlay
        if event.keyCode == 53 { // Escape
            overlayDelegate?.translationOverlayDidDismiss()
            return
        }

        super.keyDown(with: event)
    }
}

// MARK: - TranslationOverlayView

/// Custom NSView for drawing translated text overlay.
/// Positions translated text at the original text locations with styling.
final class TranslationOverlayView: NSView {
    // MARK: - Properties

    /// OCR text observations with bounding boxes
    private let ocrResults: [OCRText]

    /// Translation results for each OCR text
    private let translations: [TranslationResult]

    /// Display info for coordinate conversion
    private let displayInfo: DisplayInfo

    /// Weak reference to parent window for delegate communication
    private weak var windowRef: TranslationOverlayWindow?

    /// Background color for text boxes
    private let boxBackgroundColor = NSColor.black.withAlphaComponent(0.85)

    /// Text color
    private let textColor = NSColor.white

    /// Border color
    private let borderColor = NSColor.white.withAlphaComponent(0.3)

    /// Tracking area for mouse events
    private var trackingArea: NSTrackingArea?

    // MARK: - Initialization

    init(
        frame frameRect: NSRect,
        ocrResults: [OCRText],
        translations: [TranslationResult],
        displayInfo: DisplayInfo,
        window: TranslationOverlayWindow
    ) {
        self.ocrResults = ocrResults
        self.translations = translations
        self.displayInfo = displayInfo
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

        // Draw each translation at its corresponding OCR position
        for (index, ocrText) in ocrResults.enumerated() {
            guard index < translations.count else { break }

            let translation = translations[index]
            drawTranslation(translation, at: ocrText.boundingBox, context: context)
        }
    }

    /// Draws a translation text box at the specified normalized bounding box.
    private func drawTranslation(
        _ translation: TranslationResult,
        at boundingBox: CGRect,
        context: CGContext
    ) {
        // Convert normalized bounding box to screen coordinates
        let screenRect = convertToScreenCoordinates(boundingBox)

        // Skip if outside visible area
        guard screenRect.intersects(bounds) else { return }

        // Calculate font size based on bounding box height
        let fontSize = calculateFontSize(for: screenRect)

        // Create attributed string for translation
        let text = translation.translatedText
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Calculate text size
        let textSize = attributedString.size()

        // Adjust box size to fit text, maintaining minimum dimensions
        let boxWidth = max(screenRect.width, textSize.width + 16)
        let boxHeight = max(screenRect.height, textSize.height + 12)

        // Center the box on the original text position
        let boxOrigin = CGPoint(
            x: screenRect.midX - boxWidth / 2,
            y: screenRect.midY - boxHeight / 2
        )

        let boxRect = CGRect(origin: boxOrigin, size: CGSize(width: boxWidth, height: boxHeight))

        // Draw background
        drawBackgroundBox(boxRect, context: context)

        // Draw text
        let textPoint = CGPoint(
            x: boxRect.midX - textSize.width / 2,
            y: boxRect.midY - textSize.height / 2
        )

        attributedString.draw(at: textPoint)
    }

    /// Draws the background box with rounded corners and border.
    private func drawBackgroundBox(_ rect: CGRect, context: CGContext) {
        let cornerRadius: CGFloat = 6

        context.saveGState()

        // Draw rounded rectangle
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        // Fill
        context.setFillColor(boxBackgroundColor.cgColor)
        context.addPath(path)
        context.fillPath()

        // Stroke
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()

        context.restoreGState()
    }

    /// Converts normalized bounding box to screen coordinates.
    private func convertToScreenCoordinates(_ normalizedBox: CGRect) -> CGRect {
        CGRect(
            x: normalizedBox.minX * bounds.width,
            y: normalizedBox.minY * bounds.height,
            width: normalizedBox.width * bounds.width,
            height: normalizedBox.height * bounds.height
        )
    }

    /// Calculates appropriate font size based on bounding box height.
    private func calculateFontSize(for rect: CGRect) -> CGFloat {
        // Base font size on box height, with reasonable bounds
        let minFontSize: CGFloat = 12
        let maxFontSize: CGFloat = 24
        let calculatedSize = rect.height * 0.7
        return max(minFontSize, min(maxFontSize, calculatedSize))
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Check if click is outside any translation box
        let point = convert(event.locationInWindow, from: nil)

        var isOutside = true
        for ocrText in ocrResults {
            let screenRect = convertToScreenCoordinates(ocrText.boundingBox)
            if screenRect.contains(point) {
                isOutside = false
                break
            }
        }

        if isOutside {
            // Notify delegate to dismiss
            windowRef?.overlayDelegate?.translationOverlayDidDismiss()
        }
    }
}

// MARK: - TranslationOverlayController

/// Controller for managing translation overlay lifecycle.
@MainActor
final class TranslationOverlayController {
    // MARK: - Properties

    /// Shared instance
    static let shared = TranslationOverlayController()

    /// The current overlay window
    private var overlayWindow: TranslationOverlayWindow?

    /// Delegate for overlay events
    weak var overlayDelegate: TranslationOverlayDelegate?

    /// Callback for when overlay is dismissed
    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Presents translation overlay with the given OCR and translation results.
    /// - Parameters:
    ///   - ocrResult: The OCR result containing text observations
    ///   - translations: Array of translation results
    func presentOverlay(
        ocrResult: OCRResult,
        translations: [TranslationResult]
    ) {
        // Dismiss any existing overlay
        dismissOverlay()

        guard let screen = NSScreen.main else { return }

        // Create display info for the main screen
        let displayInfo = DisplayInfo(
            id: CGMainDisplayID(),
            name: screen.localizedName,
            frame: screen.frame,
            scaleFactor: screen.backingScaleFactor,
            isPrimary: true
        )

        // Create overlay window
        let overlay = TranslationOverlayWindow(
            screen: screen,
            displayInfo: displayInfo,
            ocrResults: ocrResult.observations,
            translations: translations
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

// MARK: - TranslationOverlayController + TranslationOverlayDelegate

extension TranslationOverlayController: TranslationOverlayDelegate {
    func translationOverlayDidDismiss() {
        dismissOverlay()
        onDismiss?()
    }
}
