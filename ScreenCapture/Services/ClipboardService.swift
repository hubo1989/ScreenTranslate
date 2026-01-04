import Foundation
import AppKit
import CoreGraphics

/// Service for copying screenshots to the system clipboard.
/// Uses NSPasteboard for compatibility with all macOS applications.
@MainActor
struct ClipboardService: Sendable {
    // MARK: - Public API

    /// Copies an image with annotations to the system clipboard.
    /// - Parameters:
    ///   - image: The base image to copy
    ///   - annotations: Annotations to composite onto the image
    /// - Throws: ScreenCaptureError.clipboardWriteFailed if the operation fails
    func copy(_ image: CGImage, annotations: [Annotation]) throws {
        // Composite annotations if any exist
        let finalImage: CGImage
        if annotations.isEmpty {
            finalImage = image
        } else {
            finalImage = try compositeAnnotations(annotations, onto: image)
        }

        // Convert to NSImage
        let nsImage = NSImage(
            cgImage: finalImage,
            size: NSSize(width: finalImage.width, height: finalImage.height)
        )

        // Write to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write both PNG and TIFF for maximum compatibility
        guard pasteboard.writeObjects([nsImage]) else {
            throw ScreenCaptureError.clipboardWriteFailed
        }
    }

    /// Copies an image (without annotations) to the system clipboard.
    /// - Parameter image: The image to copy
    /// - Throws: ScreenCaptureError.clipboardWriteFailed if the operation fails
    func copy(_ image: CGImage) throws {
        try copy(image, annotations: [])
    }

    /// Checks if the clipboard currently contains an image.
    var hasImage: Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.tiff.rawValue,
            NSPasteboard.PasteboardType.png.rawValue
        ])
    }

    // MARK: - Annotation Compositing

    /// Composites annotations onto an image.
    /// - Parameters:
    ///   - annotations: The annotations to draw
    ///   - image: The base image
    /// - Returns: A new CGImage with annotations rendered
    /// - Throws: ScreenCaptureError if compositing fails
    private func compositeAnnotations(
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
            throw ScreenCaptureError.clipboardWriteFailed
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
            throw ScreenCaptureError.clipboardWriteFailed
        }

        return result
    }

    /// Renders a single annotation into a graphics context.
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
        let rect = CGRect(
            x: annotation.rect.origin.x,
            y: imageHeight - annotation.rect.origin.y - annotation.rect.height,
            width: annotation.rect.width,
            height: annotation.rect.height
        )

        context.setStrokeColor(annotation.style.color.cgColor)
        context.setLineWidth(annotation.style.lineWidth)
        context.stroke(rect)
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

        let font = NSFont(name: annotation.style.fontName, size: annotation.style.fontSize)
            ?? NSFont.systemFont(ofSize: annotation.style.fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: annotation.style.color.nsColor
        ]

        let attributedString = NSAttributedString(string: annotation.content, attributes: attributes)
        let position = CGPoint(
            x: annotation.position.x,
            y: imageHeight - annotation.position.y - annotation.style.fontSize
        )

        context.saveGState()
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = position
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

// MARK: - Shared Instance

extension ClipboardService {
    /// Shared instance for convenience
    @MainActor static let shared = ClipboardService()
}
