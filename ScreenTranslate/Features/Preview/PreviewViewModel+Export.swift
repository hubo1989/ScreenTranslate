import Foundation
import SwiftUI
import AppKit

extension PreviewViewModel {
    func copyToClipboard() {
        guard !isCopying else { return }
        isCopying = true

        do {
            try clipboardService.copy(image, annotations: annotations)
        } catch {
            errorMessage = NSLocalizedString("error.clipboard.write.failed", comment: "Failed to copy to clipboard")
            clearError()
        }

        isCopying = false
    }

    func saveScreenshot() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            await performSave()
        }
    }

    func performSave() async {
        defer { isSaving = false }

        let directory = settings.saveLocation
        let format = settings.defaultFormat
        let quality: Double
        switch format {
        case .jpeg:
            quality = settings.jpegQuality
        case .heic:
            quality = settings.heicQuality
        case .png:
            quality = 1.0
        }

        let fileURL = imageExporter.generateFileURL(in: directory, format: format)

        do {
            try imageExporter.save(
                image,
                annotations: annotations,
                to: fileURL,
                format: format,
                quality: quality
            )

            screenshot = screenshot.saved(to: fileURL)
            recentCapturesStore.add(filePath: fileURL, image: image)
            onSave?(fileURL)
            hide()
        } catch let error as ScreenTranslateError {
            handleSaveError(error)
        } catch {
            errorMessage = NSLocalizedString("error.save.unknown", comment: "An unexpected error occurred while saving")
            clearError()
        }
    }

    func handleSaveError(_ error: ScreenTranslateError) {
        switch error {
        case .invalidSaveLocation(let url):
            errorMessage = String(
                format: NSLocalizedString("error.save.location.invalid.detail", comment: ""),
                url.path
            )
        case .diskFull:
            errorMessage = NSLocalizedString("error.disk.full", comment: "Not enough disk space")
        case .exportEncodingFailed(let format):
            errorMessage = String(
                format: NSLocalizedString("error.export.encoding.failed.detail", comment: ""),
                format.displayName
            )
        default:
            errorMessage = error.localizedDescription
        }
        clearError()
    }

    func dismissSuccessMessage() {
        saveSuccessMessage = nil
    }

    func dismissCopySuccessMessage() {
        copySuccessMessage = nil
    }
}
