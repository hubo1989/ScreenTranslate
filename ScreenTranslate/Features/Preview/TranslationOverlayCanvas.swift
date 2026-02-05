import SwiftUI
import AppKit

struct TranslationOverlayCanvas: View {
    let ocrResult: OCRResult?
    let translations: [TranslationResult]
    let image: CGImage
    let canvasSize: CGSize
    let isVisible: Bool
    
    var body: some View {
        if isVisible, let ocrResult = ocrResult, !translations.isEmpty {
            Canvas { context, size in
                drawTranslations(
                    context: &context,
                    ocrResult: ocrResult,
                    translations: translations,
                    size: size
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .allowsHitTesting(false)
        }
    }
    
    private func drawTranslations(
        context: inout GraphicsContext,
        ocrResult: OCRResult,
        translations: [TranslationResult],
        size: CGSize
    ) {
        for (index, observation) in ocrResult.observations.enumerated() {
            guard index < translations.count else { break }
            
            let translation = translations[index]
            guard !translation.translatedText.isEmpty else { continue }
            
            let pixelRect = convertNormalizedToPixels(
                normalizedRect: observation.boundingBox,
                imageSize: size
            )
            
            drawTranslation(
                context: &context,
                text: translation.translatedText,
                rect: pixelRect
            )
        }
    }
    
    private func convertNormalizedToPixels(
        normalizedRect: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        CGRect(
            x: normalizedRect.origin.x * imageSize.width,
            y: (1 - normalizedRect.origin.y - normalizedRect.height) * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )
    }
    
    private func drawTranslation(
        context: inout GraphicsContext,
        text: String,
        rect: CGRect
    ) {
        let backgroundColor = sampleBackgroundColor(at: rect)
        let textColor = calculateContrastingColor(for: backgroundColor)
        let fontSize = calculateFontSize(for: rect)
        
        let backgroundPath = Path(roundedRect: rect, cornerRadius: 2)
        context.fill(backgroundPath, with: .color(backgroundColor.opacity(0.85)))
        
        let font = Font.system(size: fontSize, weight: .medium)
        let resolvedText = context.resolve(Text(text).font(font).foregroundColor(textColor))
        
        let textSize = resolvedText.measure(in: rect.size)
        let textOrigin = CGPoint(
            x: rect.origin.x + (rect.width - textSize.width) / 2,
            y: rect.origin.y + (rect.height - textSize.height) / 2
        )
        
        context.draw(resolvedText, at: textOrigin, anchor: .topLeading)
    }
    
    private func sampleBackgroundColor(at rect: CGRect) -> Color {
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
        
        for point in samplePoints {
            if let color = samplePixelColor(at: point) {
                totalRed += color.red
                totalGreen += color.green
                totalBlue += color.blue
                validSamples += 1
            }
        }
        
        guard validSamples > 0 else {
            return Color.black.opacity(0.7)
        }
        
        return Color(
            red: totalRed / CGFloat(validSamples),
            green: totalGreen / CGFloat(validSamples),
            blue: totalBlue / CGFloat(validSamples)
        )
    }
    
    private func samplePixelColor(at point: CGPoint) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
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
        
        return (red, green, blue)
    }
    
    private func calculateContrastingColor(for backgroundColor: Color) -> Color {
        let nsColor = NSColor(backgroundColor)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return .white
        }
        
        // W3C luminance formula: 0.299*R + 0.587*G + 0.114*B
        let luminance = 0.299 * rgbColor.redComponent + 0.587 * rgbColor.greenComponent + 0.114 * rgbColor.blueComponent
        
        return luminance > 0.5 ? .black : .white
    }
    
    private func calculateFontSize(for rect: CGRect) -> CGFloat {
        let baseFontSize = rect.height * 0.75
        return max(10, min(baseFontSize, 32))
    }
}
