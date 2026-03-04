import Foundation
import CoreGraphics
import SwiftUI

/// Tool for creating numbered label annotations (①②③...).
/// User clicks to place a numbered circle.
@MainActor
struct NumberLabelTool: AnnotationTool {
    // MARK: - Properties

    let toolType: AnnotationToolType = .numberLabel

    var strokeStyle: StrokeStyle = .default

    var textStyle: TextStyle = .default

    /// Current number to display (auto-increments after each placement)
    var currentNumber: Int = 1

    /// Circle size (diameter)
    var circleSize: CGFloat = 24

    /// Label color
    var labelColor: CodableColor = CodableColor(.red)

    private var pendingPosition: CGPoint?

    // MARK: - AnnotationTool Conformance

    var isActive: Bool {
        pendingPosition != nil
    }

    var currentAnnotation: Annotation? {
        guard let position = pendingPosition else { return nil }
        return .numberLabel(NumberLabelAnnotation(
            position: position,
            number: currentNumber,
            size: circleSize,
            color: labelColor
        ))
    }

    mutating func beginDrawing(at point: CGPoint) {
        pendingPosition = point
    }

    mutating func continueDrawing(to point: CGPoint) {
        // Number labels don't drag, they just click
    }

    mutating func endDrawing(at point: CGPoint) -> Annotation? {
        guard let position = pendingPosition else { return nil }

        let annotation = NumberLabelAnnotation(
            position: position,
            number: currentNumber,
            size: circleSize,
            color: labelColor
        )

        // Reset and increment for next label
        pendingPosition = nil
        currentNumber += 1

        return .numberLabel(annotation)
    }

    mutating func cancelDrawing() {
        pendingPosition = nil
    }

    /// Reset the number counter back to 1
    mutating func resetNumber() {
        currentNumber = 1
    }
}
