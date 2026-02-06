import AppKit
import CoreGraphics
import CoreText
import Foundation

struct OverlayRenderer: Sendable {
    private let style: OverlayStyle

    init(style: OverlayStyle = .default) {
        self.style = style
    }

    func render(image: CGImage, segments: [BilingualSegment]) -> NSImage? {
        let width = image.width
        let height = image.height
        let imageSize = CGSize(width: CGFloat(width), height: CGFloat(height))

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for segment in segments {
            renderBilingualSegment(segment, in: context, imageSize: imageSize)
        }

        guard let resultImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: resultImage, size: NSSize(width: width, height: height))
    }

    private func renderBilingualSegment(
        _ segment: BilingualSegment,
        in context: CGContext,
        imageSize: CGSize
    ) {
        let pixelBox = segment.pixelBoundingBox(in: imageSize)
        let flippedY = imageSize.height - pixelBox.origin.y - pixelBox.height

        let originalRect = CGRect(
            x: pixelBox.origin.x,
            y: flippedY,
            width: pixelBox.width,
            height: pixelBox.height
        )

        let fontSize = calculateAdaptiveFontSize(for: originalRect)
        let font = createFont(size: fontSize)

        let translationHeight = calculateTextHeight(
            segment.translated,
            font: font,
            maxWidth: originalRect.width - style.padding.horizontal
        )

        let translationRect = CGRect(
            x: originalRect.origin.x,
            y: originalRect.origin.y - translationHeight - style.padding.vertical - 2,
            width: originalRect.width,
            height: translationHeight + style.padding.vertical
        )

        renderBackground(in: context, rect: translationRect)
        renderText(segment.translated, in: context, rect: translationRect, font: font)
    }

    private func renderBackground(in context: CGContext, rect: CGRect) {
        let bgColor = style.backgroundColor.cgColor
        context.setFillColor(bgColor)
        let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(path)
        context.fillPath()
    }

    private func renderText(_ text: String, in context: CGContext, rect: CGRect, font: CTFont) {
        let textColor = style.translationColor.cgColor

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        let textRect = CGRect(
            x: rect.origin.x + style.padding.leading,
            y: rect.origin.y + style.padding.bottom,
            width: rect.width - style.padding.horizontal,
            height: rect.height - style.padding.vertical
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)

        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private func calculateAdaptiveFontSize(for rect: CGRect) -> CGFloat {
        let baseFontSize = rect.height * 0.6
        return max(10, min(baseFontSize, style.translationFont.size))
    }

    private func createFont(size: CGFloat) -> CTFont {
        if let fontName = style.translationFont.fontName {
            if let font = CTFontCreateWithName(fontName as CFString, size, nil) as CTFont? {
                return font
            }
        }
        return CTFontCreateWithName(".AppleSystemUIFont" as CFString, size, nil)
    }

    private func calculateTextHeight(_ text: String, font: CTFont, maxWidth: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let constraintSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attributedString.length),
            nil,
            constraintSize,
            nil
        )

        return suggestedSize.height
    }
}
