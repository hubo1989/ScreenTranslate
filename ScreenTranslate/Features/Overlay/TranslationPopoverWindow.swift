import AppKit
import CoreGraphics
import SwiftUI

// MARK: - TranslationPopoverDelegate

/// Delegate protocol for translation popover events.
@MainActor
protocol TranslationPopoverDelegate: AnyObject {
    /// Called when user dismisses the popover.
    func translationPopoverDidDismiss()
}

// MARK: - TranslationPopoverWindow

/// NSPanel subclass for displaying translation results in a popover below the selection.
/// Shows original text and translated text in a styled floating panel.
final class TranslationPopoverWindow: NSPanel {
    // MARK: - Properties

    /// The anchor rectangle for the popover (in screen coordinates)
    let anchorRect: CGRect

    /// The screen this popover appears on
    let targetScreen: NSScreen

    /// Translation results to display
    private let translations: [TranslationResult]

    /// The content view handling drawing and interaction
    private var popoverView: TranslationPopoverView?

    /// Delegate for popover events
    weak var popoverDelegate: TranslationPopoverDelegate?

    /// Whether the popover is currently positioned
    private var isPositioned = false

    // MARK: - Initialization

    /// Creates a new translation popover window.
    /// - Parameters:
    ///   - anchorRect: The rectangle to anchor the popover below (screen coordinates)
    ///   - screen: The NSScreen containing the anchor
    ///   - translations: Translation results to display
    @MainActor
    init(
        anchorRect: CGRect,
        screen: NSScreen,
        translations: [TranslationResult]
    ) {
        self.anchorRect = anchorRect
        self.targetScreen = screen
        self.translations = translations

        // Initial frame - will be repositioned
        let initialFrame = CGRect(x: 0, y: 0, width: 400, height: 200)

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupPopoverView()
        positionPopover()
    }

    // MARK: - Configuration

    @MainActor
    private func configureWindow() {
        // Window properties for floating popover
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = true

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
    private func setupPopoverView() {
        let view = TranslationPopoverView(
            translations: translations,
            window: self
        )
        self.contentView = view
        self.popoverView = view
    }

    /// Positions the popover below the anchor rectangle
    @MainActor
    private func positionPopover() {
        guard let popoverView = popoverView else { return }

        // Calculate the size needed for the content
        let contentSize = popoverView.sizeThatFits(NSSize(width: 380, height: 1000))

        // Calculate position below anchor rect
        let anchorBottom = anchorRect.maxY
        let anchorCenter = anchorRect.midX

        // Position below anchor with some padding
        let padding: CGFloat = 12
        var origin = CGPoint(
            x: anchorCenter - contentSize.width / 2,
            y: anchorBottom - contentSize.height - padding
        )

        // Keep within screen bounds (horizontal)
        if origin.x < 20 {
            origin.x = 20
        } else if origin.x + contentSize.width > targetScreen.frame.width - 20 {
            origin.x = targetScreen.frame.width - contentSize.width - 20
        }

        // Keep within screen bounds (vertical - flip if needed)
        if origin.y < 20 {
            // Not enough space below, try above
            origin.y = anchorRect.minY + padding
        }

        // Ensure still within bounds
        if origin.y < 20 {
            origin.y = 20
        } else if origin.y + contentSize.height > targetScreen.frame.height - 20 {
            origin.y = targetScreen.frame.height - contentSize.height - 20
        }

        let newFrame = CGRect(origin: origin, size: contentSize)
        setFrame(newFrame, display: true)
        isPositioned = true
    }

    // MARK: - Public API

    /// Shows the popover window
    @MainActor
    func showPopover() {
        makeKeyAndOrderFront(nil)
    }

    /// Hides and closes the popover window
    @MainActor
    func hidePopover() {
        orderOut(nil)
        close()
    }

    // MARK: - NSWindow Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape key dismisses popover
        if event.keyCode == 53 { // Escape
            popoverDelegate?.translationPopoverDidDismiss()
            return
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        // Check if click is outside the popover content
        let locationInWindow = event.locationInWindow
        guard let contentView = contentView else {
            super.mouseDown(with: event)
            return
        }

        // Convert window coordinates to view coordinates
        let locationInView = contentView.convert(locationInWindow, from: nil)

        if !contentView.bounds.contains(locationInView) {
            // Click outside - dismiss
            popoverDelegate?.translationPopoverDidDismiss()
            return
        }

        super.mouseDown(with: event)
    }
}

// MARK: - TranslationPopoverView

/// Custom NSView for drawing the translation popover content.
/// Displays original and translated text with styling.
final class TranslationPopoverView: NSView {
    // MARK: - Properties

    /// Translation results to display
    private let translations: [TranslationResult]

    /// Weak reference to parent window for delegate communication
    private weak var windowRef: TranslationPopoverWindow?

    /// Background color
    private let backgroundColor = NSColor.windowBackgroundColor

    /// Border color
    private let borderColor = NSColor.separatorColor

    /// Corner radius
    private let cornerRadius: CGFloat = 12

    /// Original text color (gray)
    private let originalTextColor = NSColor.secondaryLabelColor

    /// Translated text color (black)
    private let translatedTextColor = NSColor.labelColor

    /// Copy button area (in view coordinates)
    private var copyButtonRect: CGRect?

    // MARK: - Initialization

    init(
        translations: [TranslationResult],
        window: TranslationPopoverWindow
    ) {
        self.translations = translations
        self.windowRef = window
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    /// Calculates the size needed to fit the content
    func sizeThatFits(_ size: NSSize) -> NSSize {
        let padding: CGFloat = 16
        let itemSpacing: CGFloat = 12
        let lineWidth: CGFloat = 1
        let copyButtonHeight: CGFloat = 28

        var totalHeight = padding * 2 // Top and bottom padding
        var maxWidth: CGFloat = 0

        // Calculate sizes for each translation item
        for (index, translation) in translations.enumerated() {
            // Original text
            let originalFont = NSFont.systemFont(ofSize: 13, weight: .regular)
            let originalAttrs: [NSAttributedString.Key: Any] = [
                .font: originalFont
            ]
            let originalSize = (translation.sourceText as NSString).size(
                withAttributes: originalAttrs
            )

            // Translated text
            let translatedFont = NSFont.systemFont(ofSize: 14, weight: .medium)
            let translatedAttrs: [NSAttributedString.Key: Any] = [
                .font: translatedFont
            ]
            let translatedSize = (translation.translatedText as NSString).size(
                withAttributes: translatedAttrs
            )

            // Take the wider of the two texts
            let itemWidth = max(originalSize.width, translatedSize.width)
            maxWidth = max(maxWidth, itemWidth)

            // Add height for this item
            totalHeight += originalSize.height + 4 + translatedSize.height

            // Add spacing between items (but not after last)
            if index < translations.count - 1 {
                totalHeight += itemSpacing + lineWidth
            }
        }

        // Add space for copy button
        totalHeight += copyButtonHeight + padding

        // Constrain width
        let maxAllowedWidth: CGFloat = 500
        let minAllowedWidth: CGFloat = 280
        let calculatedWidth = min(max(maxWidth, minAllowedWidth), maxAllowedWidth)

        return NSSize(width: calculatedWidth + padding * 2, height: totalHeight)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw background with shadow
        drawBackground(context: context)

        // Draw content
        var currentY: CGFloat = bounds.height - 16
        let padding: CGFloat = 16
        let itemSpacing: CGFloat = 12

        for (index, translation) in translations.enumerated() {
            // Draw original text (gray)
            currentY = drawOriginalText(
                translation.sourceText,
                at: CGPoint(x: padding, y: currentY),
                context: context
            )

            // Draw translated text (black)
            currentY = drawTranslatedText(
                translation.translatedText,
                at: CGPoint(x: padding, y: currentY - 6),
                context: context
            )

            // Draw separator between items
            if index < translations.count - 1 {
                currentY -= itemSpacing
                drawSeparator(at: currentY - 4, context: context)
                currentY -= 4
            }
        }

        // Draw copy button
        currentY -= 8
        copyButtonRect = drawCopyButton(at: CGPoint(x: padding, y: currentY), context: context)
    }

    /// Draws the popover background with rounded corners and shadow
    private func drawBackground(context: CGContext) {
        context.saveGState()

        // Create and apply shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 8
        shadow.set()

        // Draw rounded rectangle background
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 2, dy: 2),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        backgroundColor.setFill()
        path.fill()

        // Draw border
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        context.restoreGState()
    }

    /// Draws original text in gray
    private func drawOriginalText(
        _ text: String,
        at origin: CGPoint,
        context: CGContext
    ) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: originalTextColor
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let drawPoint = CGPoint(
            x: origin.x,
            y: origin.y - textSize.height
        )

        attributedString.draw(at: drawPoint)

        return origin.y - textSize.height
    }

    /// Draws translated text in black
    private func drawTranslatedText(
        _ text: String,
        at origin: CGPoint,
        context: CGContext
    ) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: translatedTextColor
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let drawPoint = CGPoint(
            x: origin.x,
            y: origin.y - textSize.height
        )

        attributedString.draw(at: drawPoint)

        return origin.y - textSize.height
    }

    /// Draws a separator line between translation items
    private func drawSeparator(at y: CGFloat, context: CGContext) {
        context.saveGState()

        let lineRect = CGRect(
            x: 16,
            y: y,
            width: bounds.width - 32,
            height: 1
        )

        let path = NSBezierPath(rect: lineRect)
        borderColor.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 1
        path.stroke()

        context.restoreGState()
    }

    /// Draws the copy button at the specified position
    private func drawCopyButton(at origin: CGPoint, context: CGContext) -> CGRect {
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 28

        let buttonRect = CGRect(
            x: origin.x,
            y: origin.y - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )

        context.saveGState()

        // Button background
        let buttonPath = NSBezierPath(
            roundedRect: buttonRect,
            xRadius: 6,
            yRadius: 6
        )

        NSColor.controlAccentColor.setFill()
        buttonPath.fill()

        // Button text
        let buttonText = "Copy"
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = (buttonText as NSString).size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: buttonRect.midX - textSize.width / 2,
            y: buttonRect.midY - textSize.height / 2
        )

        (buttonText as NSString).draw(at: textPoint, withAttributes: attributes)

        context.restoreGState()

        return buttonRect
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Check if click is on copy button
        if let buttonRect = copyButtonRect, buttonRect.contains(point) {
            copyToClipboard()
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Change cursor when hovering over copy button
        if let buttonRect = copyButtonRect, buttonRect.contains(point) {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Change cursor when hovering over copy button
        if let buttonRect = copyButtonRect, buttonRect.contains(point) {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        // Add new tracking area for mouse tracking
        let options: NSTrackingArea.Options = [
            .activeAlways,
            .mouseMoved,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - Copy Functionality

    /// Copies all translated text to clipboard
    private func copyToClipboard() {
        let combinedTranslation = translations
            .map(\.translatedText)
            .joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedTranslation, forType: .string)

        // Show brief visual feedback
        showCopyFeedback()
    }

    /// Shows visual feedback when text is copied
    private func showCopyFeedback() {
        // Brief flash effect
        let originalAlpha = alphaValue
        alphaValue = 0.7

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            animator().alphaValue = 1.0
        }

        // Restore
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.alphaValue = originalAlpha
        }
    }
}

// MARK: - TranslationPopoverController

/// Controller for managing translation popover lifecycle.
@MainActor
final class TranslationPopoverController {
    // MARK: - Properties

    /// Shared instance
    static let shared = TranslationPopoverController()

    /// The current popover window
    private var popoverWindow: TranslationPopoverWindow?

    /// Delegate for popover events
    weak var popoverDelegate: TranslationPopoverDelegate?

    /// Callback for when popover is dismissed
    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Presents translation popover with the given results.
    /// - Parameters:
    ///   - anchorRect: The rectangle to anchor below (in screen coordinates)
    ///   - translations: Array of translation results
    func presentPopover(
        anchorRect: CGRect,
        translations: [TranslationResult]
    ) {
        // Dismiss any existing popover
        dismissPopover()

        guard let screen = NSScreen.main else { return }

        // Create popover window
        let popover = TranslationPopoverWindow(
            anchorRect: anchorRect,
            screen: screen,
            translations: translations
        )
        popover.popoverDelegate = self

        self.popoverWindow = popover
        popover.showPopover()
    }

    /// Dismisses the current popover.
    func dismissPopover() {
        popoverWindow?.hidePopover()
        popoverWindow = nil
    }
}

// MARK: - TranslationPopoverController + TranslationPopoverDelegate

extension TranslationPopoverController: TranslationPopoverDelegate {
    func translationPopoverDidDismiss() {
        dismissPopover()
        onDismiss?()
    }
}
