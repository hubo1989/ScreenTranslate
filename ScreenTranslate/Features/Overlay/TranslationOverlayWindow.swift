import AppKit
import CoreGraphics
import SwiftUI

// MARK: - CGFloat Extension

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

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
/// Implements "cover original text" mode with content-aware background fill.
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

    /// The captured screenshot for background color sampling
    private let capturedImage: CGImage?

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
    ///   - capturedImage: Optional screenshot for background sampling (enables content-aware fill)
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
/// Implements content-aware fill: samples background color from original image,
/// fills text region, then renders translation with contrasting color.
final class TranslationOverlayView: NSView {
    // MARK: - Properties

    private let ocrResults: [OCRText]
    private let translations: [TranslationResult]
    private let displayInfo: DisplayInfo
    private let capturedImage: CGImage?
    private weak var windowRef: TranslationOverlayWindow?
    private var trackingArea: NSTrackingArea?

    // MARK: - Initialization

    init(
        frame frameRect: NSRect,
        ocrResults: [OCRText],
        translations: [TranslationResult],
        displayInfo: DisplayInfo,
        capturedImage: CGImage?,
        window: TranslationOverlayWindow
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
            drawTranslation(translation, at: ocrText.boundingBox, context: context)
        }
    }

    private func drawTranslation(
        _ translation: TranslationResult,
        at boundingBox: CGRect,
        context: CGContext
    ) {
        let screenRect = convertToScreenCoordinates(boundingBox)
        guard screenRect.intersects(bounds) else { return }

        let backgroundColor = sampleBackgroundColor(at: boundingBox)
        let textColor = calculateContrastingColor(for: backgroundColor)
        let fontSize = calculateFontSize(for: screenRect)
        let text = translation.translatedText

        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.boundingRect(
            with: CGSize(width: max(screenRect.width, 200), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        let fillWidth = max(screenRect.width, textSize.width + 8)
        let fillHeight = max(screenRect.height, textSize.height + 4)
        let fillRect = CGRect(
            x: screenRect.origin.x,
            y: screenRect.origin.y,
            width: fillWidth,
            height: fillHeight
        )

        context.saveGState()
        context.setFillColor(backgroundColor.cgColor)
        context.fill(fillRect)
        context.restoreGState()

        let textRect = CGRect(
            x: fillRect.origin.x + 4,
            y: fillRect.origin.y + 2,
            width: fillWidth - 8,
            height: fillHeight - 4
        )
        attributedString.draw(in: textRect)
    }

    private func sampleBackgroundColor(at normalizedBox: CGRect) -> NSColor {
        guard let image = capturedImage else {
            return .windowBackgroundColor
        }

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        let pixelRect = CGRect(
            x: normalizedBox.minX * imageWidth,
            y: normalizedBox.minY * imageHeight,
            width: normalizedBox.width * imageWidth,
            height: normalizedBox.height * imageHeight
        )

        var samples: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        let samplePoints = [
            CGPoint(x: max(0, pixelRect.minX - 2), y: pixelRect.midY),
            CGPoint(x: min(imageWidth - 1, pixelRect.maxX + 2), y: pixelRect.midY),
            CGPoint(x: pixelRect.midX, y: max(0, pixelRect.minY - 2)),
            CGPoint(x: pixelRect.midX, y: min(imageHeight - 1, pixelRect.maxY + 2))
        ]

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return .windowBackgroundColor
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        for point in samplePoints {
            let x = Int(point.x.clamped(to: 0...imageWidth - 1))
            let y = Int(point.y.clamped(to: 0...imageHeight - 1))
            let offset = y * bytesPerRow + x * bytesPerPixel

            if offset >= 0 && offset + 2 < CFDataGetLength(data) {
                let red = CGFloat(bytes[offset]) / 255.0
                let green = CGFloat(bytes[offset + 1]) / 255.0
                let blue = CGFloat(bytes[offset + 2]) / 255.0
                samples.append((r: red, g: green, b: blue))
            }
        }

        guard !samples.isEmpty else { return .windowBackgroundColor }

        let avgR = samples.map(\.r).reduce(0, +) / CGFloat(samples.count)
        let avgG = samples.map(\.g).reduce(0, +) / CGFloat(samples.count)
        let avgB = samples.map(\.b).reduce(0, +) / CGFloat(samples.count)

        return NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }

    private func calculateContrastingColor(for backgroundColor: NSColor) -> NSColor {
        guard let rgbColor = backgroundColor.usingColorSpace(.deviceRGB) else {
            return .black
        }

        let luminance = 0.299 * rgbColor.redComponent +
                        0.587 * rgbColor.greenComponent +
                        0.114 * rgbColor.blueComponent

        return luminance > 0.5 ? .black : .white
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
        let maxFontSize: CGFloat = 32
        let calculatedSize = rect.height * 0.75
        return max(minFontSize, min(maxFontSize, calculatedSize))
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        var isOutside = true
        for ocrText in ocrResults {
            let screenRect = convertToScreenCoordinates(ocrText.boundingBox)
            let expandedRect = screenRect.insetBy(dx: -20, dy: -10)
            if expandedRect.contains(point) {
                isOutside = false
                break
            }
        }

        if isOutside {
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

        let overlay = TranslationOverlayWindow(
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

// MARK: - TranslationOverlayController + TranslationOverlayDelegate

extension TranslationOverlayController: TranslationOverlayDelegate {
    func translationOverlayDidDismiss() {
        dismissOverlay()
        onDismiss?()
    }
}
