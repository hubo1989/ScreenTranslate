import Foundation
import CoreGraphics

/// Tool for drawing freehand path annotations.
/// User drags to create a continuous path of points.
@MainActor
struct FreehandTool: AnnotationTool {
    // MARK: - Properties

    let toolType: AnnotationToolType = .freehand

    var strokeStyle: StrokeStyle = .default

    var textStyle: TextStyle = .default

    private var drawingState = DrawingState()

    // MARK: - AnnotationTool Conformance

    var isActive: Bool {
        drawingState.isDrawing
    }

    var currentAnnotation: Annotation? {
        guard isActive, drawingState.points.count >= 2 else { return nil }
        return .freehand(FreehandAnnotation(points: drawingState.points, style: strokeStyle))
    }

    mutating func beginDrawing(at point: CGPoint) {
        drawingState = DrawingState(startPoint: point)
        drawingState.isDrawing = true
    }

    mutating func continueDrawing(to point: CGPoint) {
        guard isActive else { return }

        // Only add point if it's sufficiently different from the last point
        // This prevents too many points when moving slowly
        if let lastPoint = drawingState.points.last {
            let distance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
            if distance >= 2.0 {
                drawingState.points.append(point)
            }
        } else {
            drawingState.points.append(point)
        }
    }

    mutating func endDrawing(at point: CGPoint) -> Annotation? {
        guard isActive else { return nil }

        // Add final point
        continueDrawing(to: point)

        let points = drawingState.points
        drawingState.reset()

        // Need at least 2 points for a valid freehand annotation
        guard points.count >= 2 else { return nil }

        return .freehand(FreehandAnnotation(points: points, style: strokeStyle))
    }

    mutating func cancelDrawing() {
        drawingState.reset()
    }
}
