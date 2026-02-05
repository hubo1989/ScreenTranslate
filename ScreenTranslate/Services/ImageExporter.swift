import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

/// Service for exporting screenshots to PNG or JPEG files.
/// Uses CGImageDestination for efficient image encoding.
struct ImageExporter: Sendable {
    // MARK: - Constants

    /// Date formatter for generating filenames
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()

    // MARK: - Public API

    /// Exports an image to a file at the specified URL.
    /// - Parameters:
    ///   - image: The CGImage to export
    ///   - annotations: Annotations to composite onto the image
    ///   - url: The destination file URL
    ///   - format: The export format (PNG or JPEG)
    ///   - quality: JPEG quality (0.0-1.0), ignored for PNG
    /// - Throws: ScreenTranslateError if export fails
    func save(
        _ image: CGImage,
        annotations: [Annotation],
        to url: URL,
        format: ExportFormat,
        quality: Double = 0.9
    ) throws {
        // Composite annotations onto the image if any exist
        let finalImage: CGImage
        if annotations.isEmpty {
            finalImage = image
        } else {
            finalImage = try compositeAnnotations(annotations, onto: image)
        }

        // Verify parent directory exists and is writable
        let directory = url.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: directory.path) else {
            throw ScreenTranslateError.invalidSaveLocation(directory)
        }

        // Check for available disk space (rough estimate: 4 bytes per pixel for PNG)
        let estimatedSize = Int64(finalImage.width * finalImage.height * 4)
        do {
            let resourceValues = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacity,
               Int64(availableCapacity) < estimatedSize {
                throw ScreenTranslateError.diskFull
            }
        } catch let error as ScreenTranslateError {
            throw error
        } catch {
            // Ignore disk space check errors, proceed with save
        }

        // Create image destination
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.uti.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenTranslateError.exportEncodingFailed(format: format)
        }

        // Configure export options
        var options: [CFString: Any] = [:]
        if format == .jpeg || format == .heic {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        // Add image and finalize
        CGImageDestinationAddImage(destination, finalImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenTranslateError.exportEncodingFailed(format: format)
        }
    }

    /// Generates a filename with the current timestamp.
    /// - Parameter format: The export format to determine file extension
    /// - Returns: A filename like "Screenshot 2024-01-15 at 14.30.45.png"
    func generateFilename(format: ExportFormat) -> String {
        let timestamp = Self.dateFormatter.string(from: Date())
        return "Screenshot \(timestamp).\(format.fileExtension)"
    }

    /// Generates a full file URL for saving.
    /// - Parameters:
    ///   - directory: The save directory
    ///   - format: The export format
    /// - Returns: A URL with a unique filename
    func generateFileURL(in directory: URL, format: ExportFormat) -> URL {
        let filename = generateFilename(format: format)
        var url = directory.appendingPathComponent(filename)

        // Ensure unique filename if file already exists
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let baseName = "Screenshot \(Self.dateFormatter.string(from: Date())) (\(counter))"
            url = directory.appendingPathComponent("\(baseName).\(format.fileExtension)")
            counter += 1
        }

        return url
    }

    /// Estimates the file size for an image in the given format.
    /// - Parameters:
    ///   - image: The image to estimate size for
    ///   - format: The export format
    ///   - quality: JPEG quality (affects JPEG estimate)
    /// - Returns: Estimated file size in bytes
    func estimateFileSize(
        for image: CGImage,
        format: ExportFormat,
        quality: Double = 0.9
    ) -> Int {
        let pixelCount = image.width * image.height

        switch format {
        case .png:
            // PNG is lossless, estimate ~4 bytes per pixel (varies with content)
            return pixelCount * 4
        case .jpeg:
            // JPEG size varies with quality and content
            // At quality 0.9, roughly 0.5-1.0 bytes per pixel
            let bytesPerPixel = 0.5 + (0.5 * quality)
            return Int(Double(pixelCount) * bytesPerPixel)
        case .heic:
            // HEIC has better compression than JPEG
            // At quality 0.9, roughly 0.3-0.6 bytes per pixel
            let bytesPerPixel = 0.3 + (0.3 * quality)
            return Int(Double(pixelCount) * bytesPerPixel)
        }
    }

    // MARK: - Annotation Compositing

    /// Composites annotations onto an image.
    /// - Parameters:
    ///   - annotations: The annotations to draw
    ///   - image: The base image
    /// - Returns: A new CGImage with annotations rendered
    /// - Throws: ScreenTranslateError if compositing fails
    func compositeAnnotations(
        _ annotations: [Annotation],
        onto image: CGImage
    ) throws -> CGImage {
        let width = image.width
        let height = image.height

        // Create drawing context
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

        // Draw base image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Configure for drawing annotations
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw each annotation
        for annotation in annotations {
            renderAnnotation(annotation, in: context, imageHeight: CGFloat(height))
        }

        // Create final image
        guard let result = context.makeImage() else {
            throw ScreenTranslateError.exportEncodingFailed(format: .png)
        }

        return result
    }

    /// Renders a single annotation into a graphics context.
    /// - Parameters:
    ///   - annotation: The annotation to render
    ///   - context: The graphics context
    ///   - imageHeight: The image height (for coordinate transformation)
    private func renderAnnotation(
        _ annotation: Annotation,
        in context: CGContext,
        imageHeight: CGFloat
    ) {
        switch annotation {
        case .rectangle(let rect):
            renderRectangle(rect, in: context, imageHeight: imageHeight)
        case .freehand(let freehand):
            renderFreehand(freehand, in: context, imageHeight: imageHeight)
        case .arrow(let arrow):
            renderArrow(arrow, in: context, imageHeight: imageHeight)
        case .text(let text):
            renderText(text, in: context, imageHeight: imageHeight)
        }
    }

    /// Renders a rectangle annotation.
    private func renderRectangle(
        _ annotation: RectangleAnnotation,
        in context: CGContext,
        imageHeight: CGFloat
    ) {
        // Transform from SwiftUI coordinates (origin top-left) to CG coordinates (origin bottom-left)
        let rect = CGRect(
            x: annotation.rect.origin.x,
            y: imageHeight - annotation.rect.origin.y - annotation.rect.height,
            width: annotation.rect.width,
            height: annotation.rect.height
        )

        if annotation.isFilled {
            // Filled rectangle - solid color to hide underlying content
            context.setFillColor(annotation.style.color.cgColor)
            context.fill(rect)
        } else {
            // Hollow rectangle - outline only
            context.setStrokeColor(annotation.style.color.cgColor)
            context.setLineWidth(annotation.style.lineWidth)
            context.stroke(rect)
        }
    }

    /// Renders a freehand annotation.
    private func renderFreehand(
        _ annotation: FreehandAnnotation,
        in context: CGContext,
        imageHeight: CGFloat
    ) {
        guard annotation.points.count >= 2 else { return }

        context.setStrokeColor(annotation.style.color.cgColor)
        context.setLineWidth(annotation.style.lineWidth)

        // Transform points and draw path
        context.beginPath()
        let firstPoint = annotation.points[0]
        context.move(to: CGPoint(x: firstPoint.x, y: imageHeight - firstPoint.y))

        for point in annotation.points.dropFirst() {
            context.addLine(to: CGPoint(x: point.x, y: imageHeight - point.y))
        }

        context.strokePath()
    }

    /// Renders an arrow annotation.
    private func renderArrow(
        _ annotation: ArrowAnnotation,
        in context: CGContext,
        imageHeight: CGFloat
    ) {
        // Transform from SwiftUI coordinates (origin top-left) to CG coordinates (origin bottom-left)
        let start = CGPoint(x: annotation.startPoint.x, y: imageHeight - annotation.startPoint.y)
        let end = CGPoint(x: annotation.endPoint.x, y: imageHeight - annotation.endPoint.y)
        let lineWidth = annotation.style.lineWidth

        context.setStrokeColor(annotation.style.color.cgColor)
        context.setFillColor(annotation.style.color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw the main line
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Draw the arrowhead
        let arrowHeadLength = max(lineWidth * 4, 12)
        let arrowHeadAngle: CGFloat = .pi / 6

        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)

        let arrowPoint1 = CGPoint(
            x: end.x - arrowHeadLength * cos(angle - arrowHeadAngle),
            y: end.y - arrowHeadLength * sin(angle - arrowHeadAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowHeadLength * cos(angle + arrowHeadAngle),
            y: end.y - arrowHeadLength * sin(angle + arrowHeadAngle)
        )

        context.beginPath()
        context.move(to: end)
        context.addLine(to: arrowPoint1)
        context.addLine(to: arrowPoint2)
        context.closePath()
        context.fillPath()
    }

    /// Renders a text annotation.
    private func renderText(
        _ annotation: TextAnnotation,
        in context: CGContext,
        imageHeight: CGFloat
    ) {
        guard !annotation.content.isEmpty else { return }

        // Create attributed string
        let font = NSFont(name: annotation.style.fontName, size: annotation.style.fontSize)
            ?? NSFont.systemFont(ofSize: annotation.style.fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: annotation.style.color.nsColor
        ]

        let attributedString = NSAttributedString(string: annotation.content, attributes: attributes)

        // Draw text at position (transform Y coordinate)
        let position = CGPoint(
            x: annotation.position.x,
            y: imageHeight - annotation.position.y - annotation.style.fontSize
        )

        // Save context state
        context.saveGState()

        // Create line and draw
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = position
        CTLineDraw(line, context)

        // Restore context state
        context.restoreGState()
    }
}

// MARK: - Translation Overlay Compositing

extension ImageExporter {
    /// Composites translation overlays onto an image.
    /// - Parameters:
    ///   - image: The base image
    ///   - ocrResult: The OCR result containing text positions
    ///   - translations: The translated texts
    /// - Returns: A new CGImage with translations rendered
    /// - Throws: ScreenTranslateError if compositing fails
    func compositeTranslations(
        _ image: CGImage,
        ocrResult: OCRResult,
        translations: [TranslationResult]
    ) throws -> CGImage {
        let width = image.width
        let height = image.height
        let imageSize = CGSize(width: CGFloat(width), height: CGFloat(height))

        // Create drawing context
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

        // Draw base image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw each translation overlay
        for (index, observation) in ocrResult.observations.enumerated() {
            guard index < translations.count else { break }

            let translation = translations[index]
            guard !translation.translatedText.isEmpty else { continue }

            // Convert normalized bounding box to pixel coordinates
            let pixelRect = convertNormalizedToPixels(
                normalizedRect: observation.boundingBox,
                imageSize: imageSize
            )

            // Convert to CG coordinates (origin at bottom-left)
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

        // Create final image
        guard let result = context.makeImage() else {
            throw ScreenTranslateError.exportEncodingFailed(format: .png)
        }

        return result
    }

    /// Converts normalized bounding box (0-1) to pixel coordinates
    private func convertNormalizedToPixels(
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

    private func renderTranslationOverlay(
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

    private func createColorWithAlpha(_ color: CGColor, alpha: CGFloat) -> CGColor {
        guard let components = color.components, components.count >= 3 else {
            return CGColor(gray: 0, alpha: alpha)
        }
        return CGColor(red: components[0], green: components[1], blue: components[2], alpha: alpha)
    }

    /// Samples the average background color from the image at the specified rect
    private func sampleBackgroundColor(at rect: CGRect, image: CGImage) -> CGColor {
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
            // Convert from CG coordinates to image pixel coordinates
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

    /// Calculates a contrasting text color (black or white) based on background luminance
    private func calculateContrastingColor(for backgroundColor: CGColor) -> CGColor {
        guard let components = backgroundColor.components, components.count >= 3 else {
            return CGColor(gray: 1, alpha: 1)
        }

        // W3C luminance formula: 0.299*R + 0.587*G + 0.114*B
        let luminance = 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]

        return luminance > 0.5
            ? CGColor(gray: 0, alpha: 1)
            : CGColor(gray: 1, alpha: 1)
    }

    /// Calculates appropriate font size based on the rect height
    private func calculateFontSize(for rect: CGRect) -> CGFloat {
        let baseFontSize = rect.height * 0.75
        return max(10, min(baseFontSize, 32))
    }

    /// Saves an image with translations to a file.
    /// - Parameters:
    ///   - image: The CGImage to export
    ///   - annotations: Annotations to composite onto the image
    ///   - ocrResult: The OCR result containing text positions
    ///   - translations: The translated texts
    ///   - url: The destination file URL
    ///   - format: The export format (PNG or JPEG)
    ///   - quality: JPEG quality (0.0-1.0), ignored for PNG
    /// - Throws: ScreenTranslateError if export fails
    func saveWithTranslations(
        _ image: CGImage,
        annotations: [Annotation],
        ocrResult: OCRResult?,
        translations: [TranslationResult],
        to url: URL,
        format: ExportFormat,
        quality: Double = 0.9
    ) throws {
        var finalImage = image

        // First composite annotations
        if !annotations.isEmpty {
            finalImage = try compositeAnnotations(annotations, onto: finalImage)
        }

        // Then composite translations if available
        if let ocrResult = ocrResult, !translations.isEmpty {
            finalImage = try compositeTranslations(finalImage, ocrResult: ocrResult, translations: translations)
        }

        // Verify parent directory exists and is writable
        let directory = url.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: directory.path) else {
            throw ScreenTranslateError.invalidSaveLocation(directory)
        }

        // Check for available disk space
        let estimatedSize = Int64(finalImage.width * finalImage.height * 4)
        do {
            let resourceValues = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacity,
               Int64(availableCapacity) < estimatedSize {
                throw ScreenTranslateError.diskFull
            }
        } catch let error as ScreenTranslateError {
            throw error
        } catch {
            // Ignore disk space check errors, proceed with save
        }

        // Create image destination
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.uti.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenTranslateError.exportEncodingFailed(format: format)
        }

        // Configure export options
        var options: [CFString: Any] = [:]
        if format == .jpeg || format == .heic {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        // Add image and finalize
        CGImageDestinationAddImage(destination, finalImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenTranslateError.exportEncodingFailed(format: format)
        }
    }
}

// MARK: - Shared Instance

extension ImageExporter {
    /// Shared instance for convenience
    static let shared = ImageExporter()
}
