import Foundation
import SwiftUI

// MARK: - Drawing & Annotation Methods

extension PreviewViewModel {
    // MARK: - Drawing Methods

    /// Begins a drawing gesture at the given point
    /// - Parameter point: The point in image coordinates
    func beginDrawing(at point: CGPoint) {
        guard let selectedTool else { return }

        // Apply current stroke/text styles from settings
        let strokeStyle = StrokeStyle(
            color: settings.strokeColor,
            lineWidth: settings.strokeWidth
        )
        let textStyle = TextStyle(
            color: settings.strokeColor,
            fontSize: settings.textSize,
            fontName: ".AppleSystemUIFont"
        )

        switch selectedTool {
        case .rectangle:
            rectangleTool.strokeStyle = strokeStyle
            rectangleTool.isFilled = settings.rectangleFilled
            rectangleTool.beginDrawing(at: point)
        case .freehand:
            freehandTool.strokeStyle = strokeStyle
            freehandTool.beginDrawing(at: point)
        case .arrow:
            arrowTool.strokeStyle = strokeStyle
            arrowTool.beginDrawing(at: point)
        case .text:
            textTool.textStyle = textStyle
            textTool.beginDrawing(at: point)
            // Update observable properties for text input UI
            isWaitingForTextInputInternal = true
            textInputPositionInternal = point
        }

        updateCurrentAnnotation()
    }

    /// Continues a drawing gesture to the given point
    /// - Parameter point: The point in image coordinates
    func continueDrawing(to point: CGPoint) {
        guard let selectedTool else { return }

        switch selectedTool {
        case .rectangle:
            rectangleTool.continueDrawing(to: point)
        case .freehand:
            freehandTool.continueDrawing(to: point)
        case .arrow:
            arrowTool.continueDrawing(to: point)
        case .text:
            textTool.continueDrawing(to: point)
        }

        updateCurrentAnnotation()
    }

    /// Ends a drawing gesture at the given point
    /// - Parameter point: The point in image coordinates
    func endDrawing(at point: CGPoint) {
        guard let selectedTool else { return }

        var annotation: Annotation?

        switch selectedTool {
        case .rectangle:
            annotation = rectangleTool.endDrawing(at: point)
        case .freehand:
            annotation = freehandTool.endDrawing(at: point)
        case .arrow:
            annotation = arrowTool.endDrawing(at: point)
        case .text:
            // Text tool doesn't finish on mouse up
            _ = textTool.endDrawing(at: point)
            updateCurrentAnnotation()
            return
        }

        currentAnnotationInternal = nil
        drawingUpdateCounter += 1

        if let annotation {
            addAnnotation(annotation)
        }
    }

    /// Cancels the current drawing operation
    func cancelCurrentDrawing() {
        rectangleTool.cancelDrawing()
        freehandTool.cancelDrawing()
        arrowTool.cancelDrawing()
        textTool.cancelDrawing()
        currentAnnotationInternal = nil
        isWaitingForTextInputInternal = false
        textInputPositionInternal = nil
        drawingUpdateCounter += 1
    }

    /// Updates the cached current annotation to trigger view refresh
    func updateCurrentAnnotation() {
        currentAnnotationInternal = currentTool?.currentAnnotation
        drawingUpdateCounter += 1
    }

    /// Commits the current text input and adds the annotation
    func commitTextInput() {
        if let annotation = textTool.commitText() {
            addAnnotation(annotation)
        }
        // Reset observable text input state
        isWaitingForTextInputInternal = false
        textInputPositionInternal = nil
    }

    // MARK: - Annotation Selection & Editing

    /// Tests if a point hits an annotation and returns its index
    /// - Parameter point: The point to test in image coordinates
    /// - Returns: The index of the hit annotation, or nil if none hit
    func hitTest(at point: CGPoint) -> Int? {
        // Check in reverse order (top-most first)
        for (index, annotation) in annotations.enumerated().reversed() {
            let bounds = annotation.bounds
            // Add some padding for easier selection
            let expandedBounds = bounds.insetBy(dx: -10, dy: -10)
            if expandedBounds.contains(point) {
                return index
            }
        }
        return nil
    }

    /// Selects the annotation at the given index
    func selectAnnotation(at index: Int?) {
        // Deselect any tool when selecting an annotation
        if index != nil && selectedTool != nil {
            selectedTool = nil
        }
        selectedAnnotationIndex = index
    }

    /// Deselects any selected annotation
    func deselectAnnotation() {
        selectedAnnotationIndex = nil
        isDraggingAnnotation = false
        dragStartPoint = nil
        dragOriginalPosition = nil
    }

    /// Deletes the currently selected annotation
    func deleteSelectedAnnotation() {
        guard let index = selectedAnnotationIndex else { return }
        pushUndoState()
        screenshot = screenshot.removingAnnotation(at: index)
        redoStack.removeAll()
        selectedAnnotationIndex = nil
    }

    /// Begins dragging the selected annotation
    func beginDraggingAnnotation(at point: CGPoint) {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return }

        isDraggingAnnotation = true
        dragStartPoint = point

        // Store the original position based on annotation type
        let annotation = annotations[index]
        switch annotation {
        case .rectangle(let rect):
            dragOriginalPosition = rect.rect.origin
        case .freehand(let freehand):
            dragOriginalPosition = freehand.bounds.origin
        case .arrow(let arrow):
            dragOriginalPosition = arrow.bounds.origin
        case .text(let text):
            dragOriginalPosition = text.position
        }
    }

    /// Continues dragging the selected annotation
    func continueDraggingAnnotation(to point: CGPoint) {
        guard isDraggingAnnotation,
              let index = selectedAnnotationIndex,
              let startPoint = dragStartPoint,
              let originalPosition = dragOriginalPosition,
              index < annotations.count else { return }

        let delta = CGPoint(
            x: point.x - startPoint.x,
            y: point.y - startPoint.y
        )

        let annotation = annotations[index]
        var updatedAnnotation: Annotation?

        switch annotation {
        case .rectangle(var rect):
            rect.rect.origin = CGPoint(
                x: originalPosition.x + delta.x,
                y: originalPosition.y + delta.y
            )
            updatedAnnotation = .rectangle(rect)

        case .freehand(var freehand):
            // Move all points by the delta
            let bounds = freehand.bounds
            let offsetX = originalPosition.x + delta.x - bounds.origin.x
            let offsetY = originalPosition.y + delta.y - bounds.origin.y
            freehand.points = freehand.points.map { point in
                CGPoint(x: point.x + offsetX, y: point.y + offsetY)
            }
            updatedAnnotation = .freehand(freehand)

        case .arrow(var arrow):
            // Move both start and end points by the delta
            let bounds = arrow.bounds
            let offsetX = originalPosition.x + delta.x - bounds.origin.x
            let offsetY = originalPosition.y + delta.y - bounds.origin.y
            arrow.startPoint = CGPoint(
                x: arrow.startPoint.x + offsetX,
                y: arrow.startPoint.y + offsetY
            )
            arrow.endPoint = CGPoint(
                x: arrow.endPoint.x + offsetX,
                y: arrow.endPoint.y + offsetY
            )
            updatedAnnotation = .arrow(arrow)

        case .text(var text):
            text.position = CGPoint(
                x: originalPosition.x + delta.x,
                y: originalPosition.y + delta.y
            )
            updatedAnnotation = .text(text)
        }

        if let updated = updatedAnnotation {
            // Update without pushing undo (will push on end)
            screenshot.annotations[index] = updated
            drawingUpdateCounter += 1
        }
    }

    /// Ends dragging the selected annotation
    func endDraggingAnnotation() {
        isDraggingAnnotation = false
        dragStartPoint = nil
        dragOriginalPosition = nil
    }

    /// Updates the color of the selected annotation
    func updateSelectedAnnotationColor(_ color: CodableColor) {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return }

        pushUndoState()
        let annotation = annotations[index]
        var updatedAnnotation: Annotation?

        switch annotation {
        case .rectangle(var rect):
            rect.style.color = color
            updatedAnnotation = .rectangle(rect)

        case .freehand(var freehand):
            freehand.style.color = color
            updatedAnnotation = .freehand(freehand)

        case .arrow(var arrow):
            arrow.style.color = color
            updatedAnnotation = .arrow(arrow)

        case .text(var text):
            text.style.color = color
            updatedAnnotation = .text(text)
        }

        if let updated = updatedAnnotation {
            screenshot = screenshot.replacingAnnotation(at: index, with: updated)
            redoStack.removeAll()
        }
    }

    /// Updates the stroke width of the selected annotation (rectangle/freehand/arrow)
    func updateSelectedAnnotationStrokeWidth(_ width: CGFloat) {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return }

        pushUndoState()
        let annotation = annotations[index]
        var updatedAnnotation: Annotation?

        switch annotation {
        case .rectangle(var rect):
            rect.style.lineWidth = width
            updatedAnnotation = .rectangle(rect)

        case .freehand(var freehand):
            freehand.style.lineWidth = width
            updatedAnnotation = .freehand(freehand)

        case .arrow(var arrow):
            arrow.style.lineWidth = width
            updatedAnnotation = .arrow(arrow)

        case .text:
            // Text doesn't have stroke width
            return
        }

        if let updated = updatedAnnotation {
            screenshot = screenshot.replacingAnnotation(at: index, with: updated)
            redoStack.removeAll()
        }
    }

    /// Updates the font size of the selected text annotation
    func updateSelectedAnnotationFontSize(_ size: CGFloat) {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return }

        let annotation = annotations[index]
        guard case .text(var text) = annotation else { return }

        pushUndoState()
        text.style.fontSize = size
        screenshot = screenshot.replacingAnnotation(at: index, with: .text(text))
        redoStack.removeAll()
    }

    /// Updates the isFilled state of the selected rectangle annotation
    func updateSelectedAnnotationFilled(_ isFilled: Bool) {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return }

        let annotation = annotations[index]
        guard case .rectangle(var rect) = annotation else { return }

        pushUndoState()
        rect.isFilled = isFilled
        screenshot = screenshot.replacingAnnotation(at: index, with: .rectangle(rect))
        redoStack.removeAll()
    }
}
