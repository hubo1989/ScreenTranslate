import Foundation
import SwiftUI

extension PreviewViewModel {
    func toggleCropMode() {
        isCropMode.toggle()
    }

    func beginCropSelection(at point: CGPoint) {
        guard isCropMode else { return }
        cropStartPoint = point
        cropRect = CGRect(origin: point, size: .zero)
        isCropSelecting = true
    }

    func continueCropSelection(to point: CGPoint) {
        guard isCropMode, let start = cropStartPoint else { return }

        let minX = min(start.x, point.x)
        let minY = min(start.y, point.y)
        let width = abs(point.x - start.x)
        let height = abs(point.y - start.y)

        cropRect = CGRect(x: minX, y: minY, width: width, height: height)
    }

    func endCropSelection(at point: CGPoint) {
        guard isCropMode else { return }
        continueCropSelection(to: point)
        isCropSelecting = false

        if let rect = cropRect, rect.width < 10 || rect.height < 10 {
            cropRect = nil
        }
    }

    func applyCrop() {
        guard let rect = cropRect else { return }

        let imageWidth = CGFloat(screenshot.image.width)
        let imageHeight = CGFloat(screenshot.image.height)

        let clampedRect = CGRect(
            x: max(0, rect.origin.x),
            y: max(0, rect.origin.y),
            width: min(rect.width, imageWidth - rect.origin.x),
            height: min(rect.height, imageHeight - rect.origin.y)
        )

        guard clampedRect.width >= 10, clampedRect.height >= 10 else {
            errorMessage = "Crop area is too small"
            cropRect = nil
            isCropMode = false
            return
        }

        guard let croppedImage = screenshot.image.cropping(to: clampedRect) else {
            errorMessage = "Failed to crop image"
            return
        }

        pushUndoState()

        screenshot = Screenshot(
            image: croppedImage,
            captureDate: screenshot.captureDate,
            sourceDisplay: screenshot.sourceDisplay
        )

        redoStack.removeAll()
        isCropMode = false
        cropRect = nil
        imageSizeChangeCounter += 1
    }

    func cancelCrop() {
        cropRect = nil
        isCropMode = false
        isCropSelecting = false
        cropStartPoint = nil
    }
}
