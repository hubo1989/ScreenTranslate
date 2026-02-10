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
        let aspectRatio = originalWidth / originalHeight

        // Determine layout based on aspect ratio
        // Wide image (landscape): stack vertically (original on top, translation below)
        // Tall image (portrait): side by side (original on left, translation on right)
        let isWideImage = aspectRatio >= 1.0

        if isWideImage {
            return renderSideBySideVertical(image: image, segments: segments)
        } else {
            return renderSideBySideHorizontal(image: image, segments: segments)
        }
    }

    /// Renders wide images with original on top, translation list below
    private func renderSideBySideVertical(image: CGImage, segments: [BilingualSegment]) -> CGImage? {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)

        // Calculate translation area height
        let translationFontSize: CGFloat = max(16, originalHeight * 0.025)
        let translationFont = createFont(size: translationFontSize)
        let lineHeight = translationFontSize * 1.5

        // Group segments by row for organized display
        let rows = groupIntoRows(segments, imageHeight: originalHeight)

        // Calculate required height for translations
        let maxTextWidth = originalWidth - 40  // Padding on both sides
        var totalTranslationHeight: CGFloat = 40  // Top padding

        for row in rows {
            let rowText = row.segments.map { $0.translated }.joined(separator: " ")
            let textHeight = calculateTextHeight(rowText, font: translationFont, maxWidth: maxTextWidth)
            totalTranslationHeight += textHeight + lineHeight * 0.5
        }
        totalTranslationHeight += 40  // Bottom padding

        let newHeight = originalHeight + totalTranslationHeight

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

        // Fill background
        context.setFillColor(CGColor(gray: 0.95, alpha: 1.0))  // Light gray background
        context.fill(CGRect(x: 0, y: 0, width: originalWidth, height: newHeight))

        // Draw original image at top (unchanged)
        let imageY = newHeight - originalHeight  // In CG, Y=0 is bottom
        context.draw(image, in: CGRect(x: 0, y: imageY, width: originalWidth, height: originalHeight))

        // Draw separator line
        let separatorY = imageY - 1
        context.setFillColor(CGColor(gray: 0.7, alpha: 1.0))
        context.fill(CGRect(x: 0, y: separatorY, width: originalWidth, height: 2))

        // Draw translations below
        var currentY: CGFloat = separatorY - 30  // Start below separator

        for row in rows {
            let rowText = row.segments.map { $0.translated }.joined(separator: " ")
            let textHeight = calculateTextHeight(rowText, font: translationFont, maxWidth: maxTextWidth)

            renderTranslationBlock(
                rowText,
                in: context,
                at: CGRect(x: 20, y: currentY - textHeight, width: maxTextWidth, height: textHeight),
                font: translationFont,
                color: CGColor(gray: 0.1, alpha: 1.0)  // Dark text for readability
            )

            currentY -= textHeight + lineHeight * 0.5
        }

        return context.makeImage()
    }

    /// Renders tall images with original on left, translation on right
    private func renderSideBySideHorizontal(image: CGImage, segments: [BilingualSegment]) -> CGImage? {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)

        // Translation area takes up to 50% of width or fixed width
        let translationAreaWidth = min(originalWidth * 0.5, 400)
        let newWidth = originalWidth + translationAreaWidth

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(newWidth),
                  height: Int(originalHeight),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        // Fill background
        context.setFillColor(CGColor(gray: 0.95, alpha: 1.0))  // Light gray background
        context.fill(CGRect(x: 0, y: 0, width: newWidth, height: originalHeight))

        // Draw original image on left (unchanged)
        context.draw(image, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))

        // Draw separator line
        let separatorX = originalWidth
        context.setFillColor(CGColor(gray: 0.7, alpha: 1.0))
        context.fill(CGRect(x: separatorX, y: 0, width: 2, height: originalHeight))

        // Calculate font size based on image height
        let translationFontSize: CGFloat = max(14, originalHeight * 0.02)
        let translationFont = createFont(size: translationFontSize)

        // Group segments by row
        let rows = groupIntoRows(segments, imageHeight: originalHeight)

        // Draw translations on right side
        let textAreaX = separatorX + 20
        let maxTextWidth = translationAreaWidth - 40
        let lineHeight = translationFontSize * 1.8

        var currentY: CGFloat = originalHeight - 40  // Start from top with padding

        // Draw title
        let titleFont = createFont(size: translationFontSize * 1.2)
        let title = "译文对照"
        let titleHeight = calculateTextHeight(title, font: titleFont, maxWidth: maxTextWidth)

        renderTranslationBlock(
            title,
            in: context,
            at: CGRect(x: textAreaX, y: currentY - titleHeight, width: maxTextWidth, height: titleHeight),
            font: titleFont,
            color: CGColor(gray: 0.2, alpha: 1.0)
        )

        currentY -= titleHeight + lineHeight

        // Draw separator
        context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
        context.fill(CGRect(x: textAreaX, y: currentY + lineHeight * 0.5, width: maxTextWidth, height: 1))

        // Draw each translation row
        for row in rows {
            let rowText = row.segments.map { $0.translated }.joined(separator: " ")
            let textHeight = calculateTextHeight(rowText, font: translationFont, maxWidth: maxTextWidth)

            // Check if we have enough space
            if currentY - textHeight < 20 {
                break  // Stop if running out of space
            }

            renderTranslationBlock(
                rowText,
                in: context,
                at: CGRect(x: textAreaX, y: currentY - textHeight, width: maxTextWidth, height: textHeight),
                font: translationFont,
                color: CGColor(gray: 0.1, alpha: 1.0)
            )

            currentY -= textHeight + lineHeight * 0.8
        }

        return context.makeImage()
    }

    /// Renders a block of translation text
    private func renderTranslationBlock(_ text: String, in context: CGContext, at rect: CGRect, font: CTFont, color: CGColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: color) ?? .black,
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
