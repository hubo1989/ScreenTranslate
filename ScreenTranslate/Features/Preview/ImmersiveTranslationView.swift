import SwiftUI
import AppKit

struct ImmersiveTranslationView: View {
    let image: CGImage
    let ocrResult: OCRResult?
    let translations: [TranslationResult]
    let isVisible: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let (blocks, requiredHeight) = calculateLayout(for: size)

            ZStack(alignment: .topLeading) {
                Image(image, scale: 1.0, label: Text(""))
                    .frame(width: CGFloat(image.width), height: CGFloat(image.height))
                    .position(
                        x: CGFloat(image.width) / 2,
                        y: CGFloat(image.height) / 2
                    )

                if isVisible {
                    ForEach(blocks) { block in
                        TranslationBlockView(block: block)
                    }
                }
            }
            .frame(
                width: max(CGFloat(image.width), size.width),
                height: max(requiredHeight, size.height)
            )
        }
    }
    
    private func calculateLayout(for containerSize: CGSize) -> ([TranslationBlock], CGFloat) {
        guard let ocrResult = ocrResult, !translations.isEmpty else {
            return ([], CGFloat(image.height))
        }

        var blocks: [TranslationBlock] = []
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        var maxYExtension: CGFloat = 0

        for (index, observation) in ocrResult.observations.enumerated() {
            guard index < translations.count else { break }

            let translation = translations[index]
            guard !translation.translatedText.isEmpty else { continue }

            let originalRect = convertNormalizedToPixels(
                normalizedRect: observation.boundingBox,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )

            let sampledColors = sampleColors(from: originalRect)
            let textColor = calculateContrastingColor(for: sampledColors.background)
            let backgroundColor = Color(sampledColors.background).opacity(0.1)
            let fontSize = max(originalRect.height * 0.75, 12)

            let translationHeight = calculateTextHeight(
                text: translation.translatedText,
                fontSize: fontSize,
                maxWidth: originalRect.width
            )

            let spacing: CGFloat = 4
            let translationY = originalRect.maxY + spacing

            let translationRect = CGRect(
                x: originalRect.minX,
                y: translationY,
                width: originalRect.width,
                height: translationHeight
            )

            let block = TranslationBlock(
                originalRect: originalRect,
                translationRect: translationRect,
                translation: translation,
                fontSize: fontSize,
                textColor: textColor,
                backgroundColor: backgroundColor
            )
            blocks.append(block)

            maxYExtension = max(maxYExtension, translationRect.maxY)
        }

        let requiredHeight = max(imageHeight, maxYExtension + 20)

        return (blocks, requiredHeight)
    }
    
    private func convertNormalizedToPixels(
        normalizedRect: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: normalizedRect.origin.x * imageWidth,
            y: normalizedRect.origin.y * imageHeight,
            width: normalizedRect.width * imageWidth,
            height: normalizedRect.height * imageHeight
        )
    }
    
    private func sampleColors(from rect: CGRect) -> (background: NSColor, text: NSColor) {
        let samplePoints = [
            CGPoint(x: rect.minX + 2, y: rect.minY + 2),
            CGPoint(x: rect.maxX - 2, y: rect.minY + 2),
            CGPoint(x: rect.minX + 2, y: rect.maxY - 2),
            CGPoint(x: rect.maxX - 2, y: rect.maxY - 2),
            CGPoint(x: rect.midX, y: rect.midY)
        ]
        
        var colors: [NSColor] = []
        
        for point in samplePoints {
            if let color = samplePixelColor(at: point) {
                colors.append(color)
            }
        }
        
        guard !colors.isEmpty else {
            return (.white, .black)
        }
        
        let avgRed = colors.map { $0.redComponent }.reduce(0, +) / CGFloat(colors.count)
        let avgGreen = colors.map { $0.greenComponent }.reduce(0, +) / CGFloat(colors.count)
        let avgBlue = colors.map { $0.blueComponent }.reduce(0, +) / CGFloat(colors.count)
        
        let backgroundColor = NSColor(red: avgRed, green: avgGreen, blue: avgBlue, alpha: 1.0)
        
        return (backgroundColor, backgroundColor)
    }
    
    private func samplePixelColor(at point: CGPoint) -> NSColor? {
        let x = Int(point.x)
        let y = Int(point.y)
        
        guard x >= 0, x < image.width, y >= 0, y < image.height else {
            return nil
        }
        
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel
        
        let red = CGFloat(bytes[pixelOffset]) / 255.0
        let green = CGFloat(bytes[pixelOffset + 1]) / 255.0
        let blue = CGFloat(bytes[pixelOffset + 2]) / 255.0
        
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    private func calculateContrastingColor(for backgroundColor: NSColor) -> Color {
        guard let rgbColor = backgroundColor.usingColorSpace(.deviceRGB) else {
            return .black
        }
        
        let luminance = 0.299 * rgbColor.redComponent + 0.587 * rgbColor.greenComponent + 0.114 * rgbColor.blueComponent
        
        return luminance > 0.5 ? .black : .white
    }
    
    private func calculateTextHeight(text: String, fontSize: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributedString = NSAttributedString(
            string: text,
            attributes: [.font: font]
        )
        
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        
        return boundingRect.height + 8
    }
}

struct TranslationBlockView: View {
    let block: ImmersiveTranslationView.TranslationBlock
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(block.backgroundColor)
                .frame(width: block.translationRect.width, height: block.translationRect.height)
            
            Text(block.translation.translatedText)
                .font(.system(size: block.fontSize, weight: .medium))
                .foregroundColor(block.textColor)
                .underline(pattern: .dash, color: block.textColor.opacity(0.5))
                .padding(4)
                .frame(width: block.translationRect.width, alignment: .leading)
        }
        .position(
            x: block.translationRect.midX,
            y: block.translationRect.midY
        )
    }
}

extension ImmersiveTranslationView {
    struct TranslationBlock: Identifiable {
        let id = UUID()
        let originalRect: CGRect
        let translationRect: CGRect
        let translation: TranslationResult
        let fontSize: CGFloat
        let textColor: Color
        let backgroundColor: Color
    }
}
