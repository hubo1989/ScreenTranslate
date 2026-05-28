import Foundation
import CoreGraphics

/// Tool for creating mosaic (pixelation) annotations.
/// User drags to define the region to pixelate.
@MainActor
struct MosaicTool: AnnotationTool {
    // MARK: - Properties

    let toolType: AnnotationToolType = .mosaic

    var strokeStyle: StrokeStyle = .default

    var textStyle: TextStyle = .default

    /// Block size for pixelation
    var blockSize: Int = 10

    private var drawingState = DrawingState()

    // MARK: - AnnotationTool Conformance

    var isActive: Bool {
        drawingState.isDrawing
    }

    var currentAnnotation: Annotation? {
        guard isActive else { return nil }
        let rect = calculateRect()
        guard rect.width > 0 && rect.height > 0 else { return nil }
        return .mosaic(MosaicAnnotation(rect: rect, blockSize: blockSize))
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
        let rect = calculateRect()
        drawingState.reset()

        guard rect.width >= 10 && rect.height >= 10 else { return nil }

        return .mosaic(MosaicAnnotation(rect: rect, blockSize: blockSize))
    }

    mutating func cancelDrawing() {
        drawingState.reset()
    }

    // MARK: - Private Methods

    private func calculateRect() -> CGRect {
        guard drawingState.points.count >= 2 else { return .zero }

        let start = drawingState.startPoint
        guard let end = drawingState.points.last else { return .zero }

        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
