import Foundation
import CoreGraphics

/// Tool for drawing arrow annotations.
/// User drags from the arrow tail to the arrowhead.
@MainActor
struct ArrowTool: AnnotationTool {
    // MARK: - Properties

    let toolType: AnnotationToolType = .arrow

    var strokeStyle: StrokeStyle = .default

    var textStyle: TextStyle = .default

    private var drawingState = DrawingState()

    // MARK: - AnnotationTool Conformance

    var isActive: Bool {
        drawingState.isDrawing
    }

    var currentAnnotation: Annotation? {
        guard isActive else { return nil }
        guard drawingState.points.count >= 2 else { return nil }
        let start = drawingState.startPoint
        let end = drawingState.points.last!
        return .arrow(ArrowAnnotation(startPoint: start, endPoint: end, style: strokeStyle))
    }

    mutating func beginDrawing(at point: CGPoint) {
        drawingState = DrawingState(startPoint: point)
        drawingState.isDrawing = true
    }

    mutating func continueDrawing(to point: CGPoint) {
        guard isActive else { return }
        // Only need start and current point for arrows
        if drawingState.points.count > 1 {
            drawingState.points[1] = point
        } else {
            drawingState.points.append(point)
        }
    }

    mutating func endDrawing(at point: CGPoint) -> Annotation? {
        guard isActive else { return nil }

        continueDrawing(to: point)
        let start = drawingState.startPoint
        let end = point
        drawingState.reset()

        // Only create annotation if it has meaningful length
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length >= 5 else { return nil }

        return .arrow(ArrowAnnotation(startPoint: start, endPoint: end, style: strokeStyle))
    }

    mutating func cancelDrawing() {
        drawingState.reset()
    }
}
