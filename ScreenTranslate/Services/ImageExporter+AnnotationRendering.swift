import Foundation
import CoreGraphics
import AppKit

// MARK: - Annotation Rendering

extension ImageExporter {
    /// Renders a single annotation into a graphics context.
    /// - Parameters:
    ///   - annotation: The annotation to render
    ///   - context: The graphics context
    ///   - imageHeight: The image height (for coordinate transformation)
    func renderAnnotation(
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
    func renderRectangle(
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
    func renderFreehand(
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
    func renderArrow(
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
    func renderText(
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
