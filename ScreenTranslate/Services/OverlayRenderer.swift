import AppKit
import CoreGraphics
import CoreText
import Foundation

struct OverlayRenderer: Sendable {
    private let style: OverlayStyle

    init(style: OverlayStyle = .default) {
        self.style = style
    }

    func render(image: CGImage, segments: [BilingualSegment]) -> CGImage? {
        guard !segments.isEmpty else {
            return image
        }

        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)

        let rows = groupIntoRows(segments, imageHeight: originalHeight)
        
        var rowHeights: [CGFloat] = []
        for row in rows {
            let fontSize = max(12, row.avgHeight * 0.7)
            let font = createFont(size: fontSize)
            let maxTextHeight = row.segments.map { segment in
                calculateTextHeight(segment.translated, font: font, maxWidth: originalWidth)
            }.max() ?? 20
            rowHeights.append(maxTextHeight + 10)
        }

        let totalExtraHeight = rowHeights.reduce(0, +)
        let newHeight = originalHeight + totalExtraHeight

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(originalWidth),
                  height: Int(newHeight),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        let bgColor = sampleBackgroundColor(from: image) ?? CGColor(gray: 0.1, alpha: 1.0)
        context.setFillColor(bgColor)
        context.fill(CGRect(x: 0, y: 0, width: originalWidth, height: newHeight))

        // Simple approach: draw original image at top, translations below each row
        // Calculate Y offset for each row based on how many translation gaps are below it
        
        var yOffset: CGFloat = totalExtraHeight
        
        // Draw entire original image shifted up by totalExtraHeight
        context.draw(image, in: CGRect(x: 0, y: yOffset, width: originalWidth, height: originalHeight))
        
        // Now draw translations in the gaps below each row
        for (index, row) in rows.enumerated() {
            // Translation Y position: below the original text row, accounting for offset
            // row.bottomY is in top-down coords, convert to bottom-up for drawing
            let translationY = yOffset + (originalHeight - row.bottomY) - rowHeights[index]
            
            let fontSize = max(12, row.avgHeight * 0.7)
            let font = createFont(size: fontSize)
            
            for segment in row.segments {
                let pixelBox = segment.pixelBoundingBox(in: CGSize(width: originalWidth, height: originalHeight))
                let textColor = sampleTextColor(from: image, at: pixelBox) ?? CGColor(gray: 0.9, alpha: 1.0)
                
                renderTranslation(
                    segment.translated,
                    in: context,
                    at: CGRect(x: pixelBox.origin.x, y: translationY, width: pixelBox.width * 2, height: rowHeights[index]),
                    font: font,
                    color: textColor
                )
            }
            
            // Draw dashed line below translations
            let lineY = translationY - 2
            drawDashedLine(in: context, at: CGRect(x: 0, y: lineY, width: originalWidth, height: 1), color: CGColor(gray: 0.5, alpha: 0.3))
            
            // Reduce yOffset for next iteration (translations stack from bottom)
            yOffset -= rowHeights[index]
        }

        return context.makeImage()
    }

    private func groupIntoRows(_ segments: [BilingualSegment], imageHeight: CGFloat) -> [RowInfo] {
        let sortedSegments = segments.sorted { seg1, seg2 in
            let y1 = seg1.original.boundingBox.minY
            let y2 = seg2.original.boundingBox.minY
            return y1 < y2
        }
        
        var rows: [RowInfo] = []
        let rowThreshold: CGFloat = 0.03
        
        for segment in sortedSegments {
            let segmentY = segment.original.boundingBox.minY
            
            if let lastIndex = rows.indices.last,
               abs(rows[lastIndex].normalizedY - segmentY) < rowThreshold {
                rows[lastIndex].segments.append(segment)
                let box = segment.original.boundingBox
                let pixelTop = box.minY * imageHeight
                let pixelBottom = (box.minY + box.height) * imageHeight
                rows[lastIndex].topY = min(rows[lastIndex].topY, pixelTop)
                rows[lastIndex].bottomY = max(rows[lastIndex].bottomY, pixelBottom)
            } else {
                let box = segment.original.boundingBox
                let pixelTop = box.minY * imageHeight
                let pixelBottom = (box.minY + box.height) * imageHeight
                rows.append(RowInfo(
                    segments: [segment],
                    normalizedY: segmentY,
                    topY: pixelTop,
                    bottomY: pixelBottom
                ))
            }
        }
        
        for i in rows.indices {
            let heights = rows[i].segments.map { $0.original.boundingBox.height * imageHeight }
            rows[i].avgHeight = heights.reduce(0, +) / CGFloat(heights.count)
        }
        
        return rows
    }

    private func createFont(size: CGFloat) -> CTFont {
        CTFontCreateWithName("PingFang SC" as CFString, size, nil)
    }

    private func calculateTextHeight(_ text: String, font: CTFont, maxWidth: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attrString.length),
            nil,
            CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            nil
        )
        return size.height
    }

    private func renderTranslation(_ text: String, in context: CGContext, at rect: CGRect, font: CTFont, color: CGColor) {
        // Draw semi-transparent background pad for better readability
        let bgPadColor = CGColor(white: 0.0, alpha: 0.3)  // Dark semi-transparent background
        context.setFillColor(bgPadColor)
        context.fill(rect.insetBy(dx: -4, dy: -2))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Use sampled color but ensure it's bright enough for readability
        // against the dark background pad
        let adjustedColor = ensureReadableColor(color, backgroundBrightness: 0.0)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: adjustedColor) ?? .white,
            .paragraphStyle: paragraphStyle
        ]

        let attrString = CFAttributedStringCreate(
            nil,
            text as CFString,
            attributes as CFDictionary
        )!

        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: CFAttributedStringGetLength(attrString)), path, nil)

        CTFrameDraw(frame, context)
    }

    /// Ensures text color has sufficient contrast against background
    private func ensureReadableColor(_ color: CGColor, backgroundBrightness: CGFloat) -> CGColor {
        guard let components = color.components, components.count >= 3 else {
            return CGColor(white: 1.0, alpha: 1.0)  // Default to white
        }

        let r = components[0]
        let g = components[1]
        let b = components[2]

        // Calculate relative luminance (perceived brightness)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b

        // For dark background, ensure text is bright enough
        if backgroundBrightness < 0.5 {
            // Background is dark, text should be bright
            if luminance < 0.6 {
                // Text is too dark, brighten it
                let factor = 0.8 / max(luminance, 0.1)
                return CGColor(
                    red: min(r * factor, 1.0),
                    green: min(g * factor, 1.0),
                    blue: min(b * factor, 1.0),
                    alpha: 1.0
                )
            }
        } else {
            // Background is light, text should be dark
            if luminance > 0.4 {
                // Text is too bright, darken it
                let factor = 0.2 / max(luminance, 0.1)
                return CGColor(
                    red: r * factor,
                    green: g * factor,
                    blue: b * factor,
                    alpha: 1.0
                )
            }
        }

        return color
    }

    private func sampleTextColor(from image: CGImage, at rect: CGRect) -> CGColor? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        
        let bgColor = sampleBackgroundColor(from: image)
        let bgR = bgColor.flatMap { $0.components?[0] } ?? 0
        let bgG = bgColor.flatMap { $0.components?[1] } ?? 0
        let bgB = bgColor.flatMap { $0.components?[2] } ?? 0
        
        var bestColor: CGColor?
        var maxDistance: CGFloat = 0
        
        let samplePoints: [(CGFloat, CGFloat)] = [
            (0.1, 0.3), (0.2, 0.5), (0.3, 0.3),
            (0.4, 0.5), (0.5, 0.3), (0.6, 0.5),
            (0.7, 0.3), (0.8, 0.5), (0.9, 0.3)
        ]
        
        for (xRatio, yRatio) in samplePoints {
            let sampleX = Int(rect.origin.x + rect.width * xRatio)
            let sampleY = Int(rect.origin.y + rect.height * yRatio)
            
            let cgY = Int(imageHeight) - 1 - sampleY
            
            guard sampleX >= 0, sampleX < Int(imageWidth),
                  cgY >= 0, cgY < Int(imageHeight) else { continue }
            
            let offset = cgY * bytesPerRow + sampleX * bytesPerPixel
            // ScreenCaptureKit uses BGRA format
            let b = CGFloat(ptr[offset]) / 255.0
            let g = CGFloat(ptr[offset + 1]) / 255.0
            let r = CGFloat(ptr[offset + 2]) / 255.0
            
            let distance = sqrt(pow(r - bgR, 2) + pow(g - bgG, 2) + pow(b - bgB, 2))
            
            if distance > maxDistance {
                maxDistance = distance
                bestColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            }
        }
        
        return bestColor
    }

    private func sampleBackgroundColor(from image: CGImage) -> CGColor? {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        // ScreenCaptureKit uses BGRA format
        let b = CGFloat(ptr[0]) / 255.0
        let g = CGFloat(ptr[1]) / 255.0
        let r = CGFloat(ptr[2]) / 255.0
        
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func drawDashedLine(in context: CGContext, at rect: CGRect, color: CGColor) {
        context.setStrokeColor(color)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.move(to: CGPoint(x: rect.minX, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }
}

private struct RowInfo {
    var segments: [BilingualSegment]
    var normalizedY: CGFloat
    var topY: CGFloat
    var bottomY: CGFloat
    var avgHeight: CGFloat = 0
}
