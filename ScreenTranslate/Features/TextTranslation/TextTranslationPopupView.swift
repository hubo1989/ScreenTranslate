//
//  TextTranslationPopupView.swift
//  ScreenTranslate
//
//  Created for US-004: Create TextTranslationPopup window for showing translation results
//

import AppKit
import CoreGraphics
import SwiftUI

// MARK: - TextTranslationPopupView

/// Custom NSView for drawing the text translation popup content.
/// Displays original text with source language label and translated text with target language label.
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

    /// Hover state for copy button
    private var isCopyButtonHovered = false

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
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        let copyButtonHeight: CGFloat = 28

        let maxWidth = size.width - padding * 2
        let textWidth = max(maxWidth, 200)

        // Calculate original text height
        let originalFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let originalAttrs: [NSAttributedString.Key: Any] = [
            .font: originalFont
        ]
        let originalSize = (originalText as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: originalAttrs
        )

        // Calculate translated text height
        let translatedFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let translatedAttrs: [NSAttributedString.Key: Any] = [
            .font: translatedFont
        ]
        let translatedSize = (translatedText as NSString).boundingRect(
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

        // Copy button
        totalHeight += sectionSpacing + copyButtonHeight

        // Bottom padding
        totalHeight += padding

        // Constrain width
        let maxAllowedWidth: CGFloat = 500
        let minAllowedWidth: CGFloat = 280
        let calculatedWidth = min(max(textWidth + padding * 2, minAllowedWidth), maxAllowedWidth)

        return NSSize(width: calculatedWidth, height: totalHeight)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw background with shadow
        drawBackground(context: context)

        let padding: CGFloat = 16
        let textWidth = bounds.width - padding * 2
        var currentY: CGFloat = bounds.height - padding

        // MARK: Original Text Section

        // Draw source language label
        currentY = drawLanguageLabel(
            sourceLanguage,
            at: CGPoint(x: padding, y: currentY),
            context: context
        )

        currentY -= 4

        // Draw original text
        currentY = drawText(
            originalText,
            at: CGPoint(x: padding, y: currentY),
            font: NSFont.systemFont(ofSize: 13, weight: .regular),
            color: originalTextColor,
            maxWidth: textWidth,
            context: context
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
            context: context
        )

        currentY -= 4

        // Draw translated text
        currentY = drawText(
            translatedText,
            at: CGPoint(x: padding, y: currentY),
            font: NSFont.systemFont(ofSize: 14, weight: .medium),
            color: translatedTextColor,
            maxWidth: textWidth,
            context: context
        )

        // MARK: Copy Button

        currentY -= 16
        copyButtonRect = drawCopyButton(at: CGPoint(x: padding, y: currentY), context: context)
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
        context: CGContext
    ) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: languageLabelColor
        ]

        let attributedString = NSAttributedString(string: text.uppercased(), attributes: attributes)
        let textSize = attributedString.size()

        let drawPoint = CGPoint(
            x: origin.x,
            y: origin.y - textSize.height
        )

        attributedString.draw(at: drawPoint)

        return origin.y - textSize.height
    }

    /// Draws text with word wrapping at the specified position
    private func drawText(
        _ text: String,
        at origin: CGPoint,
        font: NSFont,
        color: NSColor,
        maxWidth: CGFloat,
        context: CGContext
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let textSize = (text as NSString).boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        let drawRect = CGRect(
            x: origin.x,
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

        // Button background (highlight if hovered)
        let buttonPath = NSBezierPath(
            roundedRect: buttonRect,
            xRadius: 6,
            yRadius: 6
        )

        if isCopyButtonHovered {
            NSColor.controlAccentColor.withAlphaComponent(0.9).setFill()
        } else {
            NSColor.controlAccentColor.setFill()
        }
        buttonPath.fill()

        // Button text
        let buttonText = NSLocalizedString("common.copy", value: "Copy", comment: "Copy button text")
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
            if !isCopyButtonHovered {
                isCopyButtonHovered = true
                needsDisplay = true
            }
        } else {
            NSCursor.arrow.set()
            if isCopyButtonHovered {
                isCopyButtonHovered = false
                needsDisplay = true
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        if isCopyButtonHovered {
            isCopyButtonHovered = false
            needsDisplay = true
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Change cursor when hovering over copy button
        if let buttonRect = copyButtonRect, buttonRect.contains(point) {
            NSCursor.pointingHand.set()
            if !isCopyButtonHovered {
                isCopyButtonHovered = true
                needsDisplay = true
            }
        } else {
            NSCursor.arrow.set()
            if isCopyButtonHovered {
                isCopyButtonHovered = false
                needsDisplay = true
            }
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
