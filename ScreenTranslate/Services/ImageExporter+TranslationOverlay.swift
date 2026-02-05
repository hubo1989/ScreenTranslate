import Foundation
import CoreGraphics
import AppKit

// MARK: - Translation Overlay Compositing

extension ImageExporter {
    func compositeTranslations(
        _ image: CGImage,
        ocrResult: OCRResult,
        translations: [TranslationResult]
    ) throws -> CGImage {
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
            throw ScreenTranslateError.exportEncodingFailed(format: .png)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for (index, observation) in ocrResult.observations.enumerated() {
            guard index < translations.count else { break }

            let translation = translations[index]
            guard !translation.translatedText.isEmpty else { continue }

            let pixelRect = convertNormalizedToPixels(
                normalizedRect: observation.boundingBox,
                imageSize: imageSize
            )

            let cgRect = CGRect(
                x: pixelRect.origin.x,
                y: CGFloat(height) - pixelRect.origin.y - pixelRect.height,
                width: pixelRect.width,
                height: pixelRect.height
            )

            renderTranslationOverlay(
                context: context,
                text: translation.translatedText,
                rect: cgRect,
                image: image
            )
        }

        guard let result = context.makeImage() else {
            throw ScreenTranslateError.exportEncodingFailed(format: .png)
        }

        return result
    }

    func convertNormalizedToPixels(
        normalizedRect: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        CGRect(
            x: normalizedRect.origin.x * imageSize.width,
            y: normalizedRect.origin.y * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )
    }

    func renderTranslationOverlay(
        context: CGContext,
        text: String,
        rect: CGRect,
        image: CGImage
    ) {
        let backgroundColor = sampleBackgroundColor(at: rect, image: image)
        let textColor = calculateContrastingColor(for: backgroundColor)
        let fontSize = calculateFontSize(for: rect)

        let bgWithAlpha = createColorWithAlpha(backgroundColor, alpha: 0.85)
        context.setFillColor(bgWithAlpha)
        let backgroundPath = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
        context.addPath(backgroundPath)
        context.fillPath()

        let font = CTFontCreateWithName(".AppleSystemUIFont" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        let textBounds = CTLineGetBoundsWithOptions(line, [])
        let textX = rect.origin.x + (rect.width - textBounds.width) / 2
        let textY = rect.origin.y + (rect.height - textBounds.height) / 2 + textBounds.height * 0.25

        context.saveGState()
        context.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    func createColorWithAlpha(_ color: CGColor, alpha: CGFloat) -> CGColor {
        guard let components = color.components, components.count >= 3 else {
            return CGColor(gray: 0, alpha: alpha)
        }
        return CGColor(red: components[0], green: components[1], blue: components[2], alpha: alpha)
    }

    func sampleBackgroundColor(at rect: CGRect, image: CGImage) -> CGColor {
        let samplePoints = [
            CGPoint(x: rect.minX + 2, y: rect.minY + 2),
            CGPoint(x: rect.maxX - 2, y: rect.minY + 2),
            CGPoint(x: rect.minX + 2, y: rect.maxY - 2),
            CGPoint(x: rect.maxX - 2, y: rect.maxY - 2)
        ]

        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var validSamples = 0

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return CGColor(gray: 0, alpha: 0.7)
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        for point in samplePoints {
            let x = Int(point.x)
            let y = image.height - Int(point.y) - 1

            guard x >= 0, x < image.width, y >= 0, y < image.height else {
                continue
            }

            let pixelOffset = y * bytesPerRow + x * bytesPerPixel
            let red = CGFloat(bytes[pixelOffset]) / 255.0
            let green = CGFloat(bytes[pixelOffset + 1]) / 255.0
            let blue = CGFloat(bytes[pixelOffset + 2]) / 255.0

            totalRed += red
            totalGreen += green
            totalBlue += blue
            validSamples += 1
        }

        guard validSamples > 0 else {
            return CGColor(gray: 0, alpha: 0.7)
        }

        return CGColor(
            red: totalRed / CGFloat(validSamples),
            green: totalGreen / CGFloat(validSamples),
            blue: totalBlue / CGFloat(validSamples),
            alpha: 1.0
        )
    }

    // W3C luminance formula: 0.299*R + 0.587*G + 0.114*B
    func calculateContrastingColor(for backgroundColor: CGColor) -> CGColor {
        guard let components = backgroundColor.components, components.count >= 3 else {
            return CGColor(gray: 1, alpha: 1)
        }

        let luminance = 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]

        return luminance > 0.5
            ? CGColor(gray: 0, alpha: 1)
            : CGColor(gray: 1, alpha: 1)
    }

    func calculateFontSize(for rect: CGRect) -> CGFloat {
        let baseFontSize = rect.height * 0.75
        return max(10, min(baseFontSize, 32))
    }
}
