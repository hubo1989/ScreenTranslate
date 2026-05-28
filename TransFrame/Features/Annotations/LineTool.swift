import Foundation
import CoreGraphics

/// Tool for drawing straight line annotations.
/// User drags from start point to end point.
@MainActor
struct LineTool: AnnotationTool {
    // MARK: - Properties

    let toolType: AnnotationToolType = .line

    var strokeStyle: StrokeStyle = .default

    var textStyle: TextStyle = .default

    private var drawingState = DrawingState()

    // MARK: - AnnotationTool Conformance

    var isActive: Bool {
        drawingState.isDrawing
    }

    var currentAnnotation: Annotation? {
        guard isActive, drawingState.points.count >= 2 else { return nil }
        let start = drawingState.startPoint
        let end = drawingState.points.last!
        return .line(LineAnnotation(startPoint: start, endPoint: end, style: strokeStyle))
    }

    mutating func beginDrawing(at point: CGPoint) {
        drawingState = DrawingState(startPoint: point)
        drawingState.isDrawing = true
    }

    mutating func continueDrawing(to point: CGPoint) {
        guard isActive else { return }
        if drawingState.points.count > 1 {
            drawingState.points[1] = point
        } else {
            drawingState.points.append(point)
        }
    }

    mutating func endDrawing(at point: CGPoint) -> Annotation? {
        guard isActive else { return nil }

        continueDrawing(to: point)
        guard drawingState.points.count >= 2 else {
            drawingState.reset()
            return nil
        }

        let start = drawingState.startPoint
        let end = drawingState.points.last!
        drawingState.reset()

        // Only create annotation if it has meaningful length
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length >= 5 else { return nil }

        return .line(LineAnnotation(startPoint: start, endPoint: end, style: strokeStyle))
    }

    mutating func cancelDrawing() {
        drawingState.reset()
    }
}
