import Foundation
import CoreGraphics

/// Tool for placing text annotations.
/// User clicks to place text, then types content.
@MainActor
struct TextTool: AnnotationTool {
    // MARK: - Properties

    let toolType: AnnotationToolType = .text

    var strokeStyle: StrokeStyle = .default

    var textStyle: TextStyle = .default

    /// The position where text will be placed
    private var placementPoint: CGPoint?

    /// Whether the tool is waiting for text input
    private(set) var isPlacingText: Bool = false

    /// The current text being entered
    var currentText: String = ""

    // MARK: - AnnotationTool Conformance

    var isActive: Bool {
        isPlacingText
    }

    var currentAnnotation: Annotation? {
        guard let point = placementPoint, !currentText.isEmpty else { return nil }
        return .text(TextAnnotation(position: point, content: currentText, style: textStyle))
    }

    mutating func beginDrawing(at point: CGPoint) {
        placementPoint = point
        isPlacingText = true
        currentText = ""
    }

    mutating func continueDrawing(to point: CGPoint) {
        // Text tool doesn't use drag gestures
    }

    mutating func endDrawing(at point: CGPoint) -> Annotation? {
        // For text tool, we don't finish on mouse up
        // The text is committed when the user presses Enter or clicks elsewhere
        return nil
    }

    mutating func cancelDrawing() {
        placementPoint = nil
        isPlacingText = false
        currentText = ""
    }

    // MARK: - Text-specific Methods

    /// Commits the current text and returns the annotation
    /// - Returns: The completed text annotation, or nil if empty
    mutating func commitText() -> Annotation? {
        guard let point = placementPoint,
              !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelDrawing()
            return nil
        }

        let annotation = Annotation.text(
            TextAnnotation(position: point, content: currentText, style: textStyle)
        )

        cancelDrawing()
        return annotation
    }

    /// Updates the current text content
    /// - Parameter text: The new text content
    mutating func updateText(_ text: String) {
        currentText = text
    }

    /// The position where text input should appear
    var inputPosition: CGPoint? {
        placementPoint
    }
}
