import Foundation
import CoreGraphics

/// Protocol defining the interface for annotation tools.
/// Each tool handles mouse events and produces annotations.
@MainActor
protocol AnnotationTool {
    /// The type of annotation this tool creates
    var toolType: AnnotationToolType { get }

    /// Whether the tool is currently in use (has active drawing)
    var isActive: Bool { get }

    /// The current stroke style for the tool
    var strokeStyle: StrokeStyle { get set }

    /// The current text style (only used by TextTool)
    var textStyle: TextStyle { get set }

    /// Called when the user starts a drawing gesture (mouse down)
    /// - Parameter point: The starting point in image coordinates
    mutating func beginDrawing(at point: CGPoint)

    /// Called as the user drags during a drawing gesture
    /// - Parameter point: The current point in image coordinates
    mutating func continueDrawing(to point: CGPoint)

    /// Called when the user ends a drawing gesture (mouse up)
    /// - Parameter point: The ending point in image coordinates
    /// - Returns: The completed annotation, if any
    mutating func endDrawing(at point: CGPoint) -> Annotation?

    /// Called when the user cancels the current drawing (e.g., Escape key)
    mutating func cancelDrawing()

    /// The current in-progress annotation for preview rendering
    var currentAnnotation: Annotation? { get }
}

/// Default implementations for optional protocol requirements
extension AnnotationTool {
    var textStyle: TextStyle {
        get { .default }
        set { }
    }
}

/// State for tracking drawing progress
struct DrawingState: Sendable {
    /// The starting point of the drawing
    var startPoint: CGPoint

    /// All collected points during drawing
    var points: [CGPoint]

    /// Whether drawing is currently in progress
    var isDrawing: Bool

    init(startPoint: CGPoint = .zero) {
        self.startPoint = startPoint
        self.points = [startPoint]
        self.isDrawing = false
    }

    mutating func reset() {
        startPoint = .zero
        points = []
        isDrawing = false
    }
}
