//
//  TextTranslationPopupView.swift
//  ScreenTranslate
//
//  Created for US-004: Create TextTranslationPopup window for showing translation results
//  Updated for US-010: Integration testing and edge case handling
//

import AppKit
import CoreGraphics
import SwiftUI

// MARK: - TextTranslationPopupView

/// Custom NSView for drawing the text translation popup content.
/// Displays original text with source language label and translated text with target language label.
/// Supports RTL languages and long text truncation.
final class TextTranslationPopupView: NSView {
    // MARK: - Properties

    /// The original text that was translated
    private let originalText: String

    /// The translated text
    private let translatedText: String

    /// Source language display name
    private let sourceLanguage: String

    /// Target language display name
    private let targetLanguage: String

    /// Weak reference to parent window for delegate communication
    private weak var windowRef: TextTranslationPopupWindow?

    /// Background color (supports light/dark mode)
    private var backgroundColor: NSColor {
        NSColor.windowBackgroundColor
    }

    /// Border color (supports light/dark mode)
    private var borderColor: NSColor {
        NSColor.separatorColor
    }

    /// Corner radius
    private let cornerRadius: CGFloat = 12

    /// Original text color (secondary)
    private var originalTextColor: NSColor {
        NSColor.secondaryLabelColor
    }

    /// Translated text color (primary)
    private var translatedTextColor: NSColor {
        NSColor.labelColor
    }

    /// Language label color
    private var languageLabelColor: NSColor {
        NSColor.tertiaryLabelColor
    }

    /// Copy button area (in view coordinates)
    private var copyButtonRect: CGRect?

    /// Insert button area (in view coordinates)
    private var insertButtonRect: CGRect?

    /// Hover state for copy button
    private var isCopyButtonHovered = false

    /// Hover state for insert button
    private var isInsertButtonHovered = false

    /// Feedback state for copy button (shows checkmark)
    private var showCopySuccess = false

    /// Feedback state for insert button (shows checkmark)
    private var showInsertSuccess = false

    /// Maximum height for the popup content (for long text handling)
    static let maxContentHeight: CGFloat = 400

    /// Maximum characters to display before truncating (visual indicator)
    static let maxDisplayCharacters = 500

    /// Indicates if original text is RTL
    private let isOriginalRTL: Bool

    /// Indicates if translated text is RTL
    private let isTranslatedRTL: Bool

    // MARK: - Initialization

    init(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        window: TextTranslationPopupWindow
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.windowRef = window

        // Detect RTL for original text based on source language
        self.isOriginalRTL = Self.isRTLLanguage(sourceLanguage) || Self.containsRTLText(originalText)

        // Detect RTL for translated text based on target language
        self.isTranslatedRTL = Self.isRTLLanguage(targetLanguage) || Self.containsRTLText(translatedText)

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - RTL Detection

    /// Checks if a language code represents an RTL language
    private static func isRTLLanguage(_ languageName: String) -> Bool {
        let rtlLanguageIndicators = [
            "ARABIC", "HEBREW", "PERSIAN", "FARSI", "URDU",
            "阿拉伯语", "希伯来语", "波斯语", "乌尔都语"
        ]
        let uppercasedName = languageName.uppercased()
        return rtlLanguageIndicators.contains { uppercasedName.contains($0) }
    }

    /// Checks if text contains significant RTL characters
    private static func containsRTLText(_ text: String) -> Bool {
        var rtlCount = 0
        var ltrCount = 0

        for scalar in text.unicodeScalars {
            let value = scalar.value
            // Arabic: 0x0600-0x06FF, Arabic Extended: 0x0750-0x077F, Arabic Presentation Forms: 0xFB50-0xFDFF, 0xFE70-0xFEFF
            // Hebrew: 0x0590-0x05FF
            if (value >= 0x590 && value <= 0x5FF) || // Hebrew
               (value >= 0x600 && value <= 0x6FF) || // Arabic
               (value >= 0x750 && value <= 0x77F) || // Arabic Extended
               (value >= 0xFB50 && value <= 0xFDFF) || // Arabic Presentation Forms-A
               (value >= 0xFE70 && value <= 0xFEFF) { // Arabic Presentation Forms-B
                rtlCount += 1
            } else if (value >= 0x41 && value <= 0x5A) || (value >= 0x61 && value <= 0x7A) {
                // Basic Latin letters
                ltrCount += 1
            }
        }

        // Consider RTL if more than 30% of detected directional characters are RTL
        return rtlCount > 0 && (ltrCount == 0 || Double(rtlCount) / Double(rtlCount + ltrCount) > 0.3)
    }

    // MARK: - Layout

    /// Calculates the size needed to fit the content
    func sizeThatFits(_ size: NSSize) -> NSSize {
        let padding: CGFloat = 16
        let sectionSpacing: CGFloat = 16
        let labelHeight: CGFloat = 16
        let textSpacing: CGFloat = 4
        let separatorHeight: CGFloat = 1
        let separatorSpacing: CGFloat = 12
        let buttonHeight: CGFloat = 28
        let buttonSpacing: CGFloat = 8

        let maxWidth = size.width - padding * 2
        let textWidth = max(maxWidth, 200)

        // Truncate text for display if too long
        let displayOriginalText = truncatedText(originalText, maxLength: Self.maxDisplayCharacters)
        let displayTranslatedText = truncatedText(translatedText, maxLength: Self.maxDisplayCharacters)

        // Calculate original text height
        let originalFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let originalAttrs: [NSAttributedString.Key: Any] = [
            .font: originalFont
        ]
        let originalSize = (displayOriginalText as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: originalAttrs
        )

        // Calculate translated text height
        let translatedFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let translatedAttrs: [NSAttributedString.Key: Any] = [
            .font: translatedFont
        ]
        let translatedSize = (displayTranslatedText as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: translatedAttrs
        )

        // Total height calculation
        var totalHeight = padding // Top padding

        // Original section
        totalHeight += labelHeight + textSpacing + ceil(originalSize.height)

        // Separator
        totalHeight += separatorSpacing + separatorHeight + separatorSpacing

        // Translated section
        totalHeight += labelHeight + textSpacing + ceil(translatedSize.height)

        // Buttons row (Copy and Insert)
        totalHeight += sectionSpacing + buttonHeight

        // Bottom padding
        totalHeight += padding

        // Constrain to maximum height
        totalHeight = min(totalHeight, Self.maxContentHeight)

        // Constrain width
        let maxAllowedWidth: CGFloat = 500
        let minAllowedWidth: CGFloat = 280
        let calculatedWidth = min(max(textWidth + padding * 2, minAllowedWidth), maxAllowedWidth)

        return NSSize(width: calculatedWidth, height: totalHeight)
    }

    /// Truncates text if it exceeds maximum length, adding ellipsis
    private func truncatedText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]) + "..."
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw background with shadow
        drawBackground(context: context)

        let padding: CGFloat = 16
        let textWidth = bounds.width - padding * 2
        var currentY: CGFloat = bounds.height - padding

        // Truncate text for display if too long (US-010: Long text handling)
        let displayOriginalText = truncatedText(originalText, maxLength: Self.maxDisplayCharacters)
        let displayTranslatedText = truncatedText(translatedText, maxLength: Self.maxDisplayCharacters)

        // MARK: Original Text Section

        // Draw source language label
        currentY = drawLanguageLabel(
            sourceLanguage,
            at: CGPoint(x: padding, y: currentY),
            context: context,
            isRTL: isOriginalRTL
        )

        currentY -= 4

        // Draw original text with RTL support
        currentY = drawText(
            displayOriginalText,
            at: CGPoint(x: padding, y: currentY),
            font: NSFont.systemFont(ofSize: 13, weight: .regular),
            color: originalTextColor,
            maxWidth: textWidth,
            context: context,
            isRTL: isOriginalRTL
        )

        // MARK: Separator

        currentY -= 12
        drawSeparator(at: currentY, context: context)
        currentY -= 13

        // MARK: Translated Text Section

        // Draw target language label
        currentY = drawLanguageLabel(
            targetLanguage,
            at: CGPoint(x: padding, y: currentY),
            context: context,
            isRTL: isTranslatedRTL
        )

        currentY -= 4

        // Draw translated text with RTL support
        currentY = drawText(
            displayTranslatedText,
            at: CGPoint(x: padding, y: currentY),
            font: NSFont.systemFont(ofSize: 14, weight: .medium),
            color: translatedTextColor,
            maxWidth: textWidth,
            context: context,
            isRTL: isTranslatedRTL
        )

        // MARK: Copy Button

        currentY -= 16
        let buttons = drawButtons(at: CGPoint(x: padding, y: currentY), context: context)
        copyButtonRect = buttons.copyRect
        insertButtonRect = buttons.insertRect
    }

    /// Draws the popup background with rounded corners and shadow
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

    /// Draws a language label at the specified position
    private func drawLanguageLabel(
        _ text: String,
        at origin: CGPoint,
        context: CGContext,
        isRTL: Bool = false
    ) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let labelPadding: CGFloat = 16

        // Create paragraph style for text alignment (US-010: RTL support)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = isRTL ? .right : .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: languageLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text.uppercased(), attributes: attributes)
        let textSize = attributedString.size()

        // Adjust x position for RTL alignment
        let xPosition = isRTL ? (bounds.width - labelPadding - textSize.width) : origin.x
        let drawPoint = CGPoint(
            x: xPosition,
            y: origin.y - textSize.height
        )

        attributedString.draw(at: drawPoint)

        return origin.y - textSize.height
    }

    /// Draws text with word wrapping at the specified position (US-010: RTL support)
    private func drawText(
        _ text: String,
        at origin: CGPoint,
        font: NSFont,
        color: NSColor,
        maxWidth: CGFloat,
        context: CGContext,
        isRTL: Bool = false
    ) -> CGFloat {
        let textPadding: CGFloat = 16

        // Create paragraph style for text alignment and writing direction
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = isRTL ? .right : .left

        // Set base writing direction for proper RTL rendering
        if isRTL {
            paragraphStyle.baseWritingDirection = .rightToLeft
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = (text as NSString).boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        // Adjust x position for RTL alignment
        let xPosition = isRTL ? (bounds.width - textPadding - maxWidth) : origin.x

        let drawRect = CGRect(
            x: xPosition,
            y: origin.y - ceil(textSize.height),
            width: maxWidth,
            height: ceil(textSize.height)
        )

        (text as NSString).draw(
            in: drawRect,
            withAttributes: attributes
        )

        return origin.y - ceil(textSize.height)
    }

    /// Draws a horizontal separator line
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

    /// Draws both Copy and Insert buttons at the specified position
    private func drawButtons(at origin: CGPoint, context: CGContext) -> (copyRect: CGRect, insertRect: CGRect) {
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 28
        let buttonSpacing: CGFloat = 8

        // Copy button on the left
        let copyRect = CGRect(
            x: origin.x,
            y: origin.y - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )

        // Insert button on the right
        let insertRect = CGRect(
            x: origin.x + buttonWidth + buttonSpacing,
            y: origin.y - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )

        context.saveGState()

        // Draw Copy button
        drawButton(
            rect: copyRect,
            title: showCopySuccess ? "✓" : NSLocalizedString("common.copy", value: "Copy", comment: "Copy button text"),
            isHovered: isCopyButtonHovered,
            isSuccess: showCopySuccess,
            accentColor: NSColor.controlAccentColor,
            context: context
        )

        // Draw Insert button
        drawButton(
            rect: insertRect,
            title: showInsertSuccess ? "✓" : NSLocalizedString("common.insert", value: "Insert", comment: "Insert button text"),
            isHovered: isInsertButtonHovered,
            isSuccess: showInsertSuccess,
            accentColor: NSColor.systemGreen,
            context: context
        )

        context.restoreGState()

        return (copyRect, insertRect)
    }

    /// Draws a single button with the given properties
    private func drawButton(
        rect: CGRect,
        title: String,
        isHovered: Bool,
        isSuccess: Bool,
        accentColor: NSColor,
        context: CGContext
    ) {
        let buttonPath = NSBezierPath(
            roundedRect: rect,
            xRadius: 6,
            yRadius: 6
        )

        // Button background
        if isSuccess {
            NSColor.systemGreen.withAlphaComponent(0.9).setFill()
        } else if isHovered {
            accentColor.withAlphaComponent(0.9).setFill()
        } else {
            accentColor.setFill()
        }
        buttonPath.fill()

        // Button text
        let font = NSFont.systemFont(ofSize: isSuccess ? 16 : 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = (title as NSString).size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2
        )

        (title as NSString).draw(at: textPoint, withAttributes: attributes)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Check if click is on copy button
        if let buttonRect = copyButtonRect, buttonRect.contains(point) {
            copyToClipboard()
            return
        }

        // Check if click is on insert button
        if let buttonRect = insertButtonRect, buttonRect.contains(point) {
            insertText()
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Change cursor when hovering over buttons
        let isOverCopy = copyButtonRect?.contains(point) ?? false
        let isOverInsert = insertButtonRect?.contains(point) ?? false

        if isOverCopy || isOverInsert {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }

        // Update hover states
        var needsRedraw = false
        if isCopyButtonHovered != isOverCopy {
            isCopyButtonHovered = isOverCopy
            needsRedraw = true
        }
        if isInsertButtonHovered != isOverInsert {
            isInsertButtonHovered = isOverInsert
            needsRedraw = true
        }
        if needsRedraw {
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        var needsRedraw = false
        if isCopyButtonHovered {
            isCopyButtonHovered = false
            needsRedraw = true
        }
        if isInsertButtonHovered {
            isInsertButtonHovered = false
            needsRedraw = true
        }
        if needsRedraw {
            needsDisplay = true
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Change cursor when hovering over buttons
        let isOverCopy = copyButtonRect?.contains(point) ?? false
        let isOverInsert = insertButtonRect?.contains(point) ?? false

        if isOverCopy || isOverInsert {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }

        // Update hover states
        var needsRedraw = false
        if isCopyButtonHovered != isOverCopy {
            isCopyButtonHovered = isOverCopy
            needsRedraw = true
        }
        if isInsertButtonHovered != isOverInsert {
            isInsertButtonHovered = isOverInsert
            needsRedraw = true
        }
        if needsRedraw {
            needsDisplay = true
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

    /// Copies the translated text to clipboard
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translatedText, forType: .string)

        // Show visual feedback
        showCopyFeedback()
    }

    /// Shows visual feedback when text is copied
    private func showCopyFeedback() {
        showCopySuccess = true
        needsDisplay = true

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showCopySuccess = false
            self?.needsDisplay = true
        }
    }

    // MARK: - Insert Functionality

    /// Inserts the translated text into the focused input field
    private func insertText() {
        // Show visual feedback immediately
        showInsertFeedback()

        // Notify window to handle insertion and dismiss
        windowRef?.handleInsertText(translatedText)
    }

    /// Shows visual feedback when text is being inserted
    private func showInsertFeedback() {
        showInsertSuccess = true
        needsDisplay = true
    }

    // MARK: - Public API for Window

    /// Called by window to trigger copy action
    func performCopy() {
        copyToClipboard()
    }

    /// Called by window to trigger insert action
    func performInsert() {
        insertText()
    }
}
