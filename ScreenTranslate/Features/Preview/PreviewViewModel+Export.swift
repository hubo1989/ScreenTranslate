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

    func saveWithTranslations() {
        guard !isSavingWithTranslations else { return }
        guard hasTranslationResults else {
            errorMessage = NSLocalizedString("error.no.translations", comment: "No translations to save")
            clearError()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = generateTranslationFilename()
        panel.message = NSLocalizedString(
            "save.with.translations.message",
            comment: "Choose where to save the translated image"
        )

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self.performSaveWithTranslations(to: url)
            }
        }
    }

    func generateTranslationFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "translated-\(formatter.string(from: Date())).png"
    }

    func performSaveWithTranslations(to url: URL) async {
        isSavingWithTranslations = true
        defer { isSavingWithTranslations = false }

        let format: ExportFormat = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
            ? .jpeg
            : .png
        let quality = format == .jpeg ? settings.jpegQuality : 1.0

        do {
            try imageExporter.saveWithTranslations(
                image,
                annotations: annotations,
                ocrResult: ocrResult,
                translations: translations,
                to: url,
                format: format,
                quality: quality
            )

            recentCapturesStore.add(filePath: url, image: image)
            saveSuccessMessage = String(
                format: NSLocalizedString("save.success.message", comment: "Saved to %@"),
                url.lastPathComponent
            )
            clearSuccessMessage()
        } catch let error as ScreenTranslateError {
            handleSaveError(error)
        } catch {
            errorMessage = NSLocalizedString("error.save.unknown", comment: "An unexpected error occurred while saving")
            clearError()
        }
    }

    func clearSuccessMessage() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            saveSuccessMessage = nil
        }
    }

    func dismissSuccessMessage() {
        saveSuccessMessage = nil
    }

    func copyWithTranslations() {
        guard !isCopyingWithTranslations else { return }
        guard hasTranslationResults else {
            errorMessage = NSLocalizedString("error.no.translations", comment: "No translations to copy")
            clearError()
            return
        }

        isCopyingWithTranslations = true

        do {
            var finalImage = image

            if !annotations.isEmpty {
                finalImage = try imageExporter.compositeAnnotations(annotations, onto: finalImage)
            }

            if let ocrResult = ocrResult {
                finalImage = try imageExporter.compositeTranslations(
                    finalImage,
                    ocrResult: ocrResult,
                    translations: translations
                )
            }

            let nsImage = NSImage(
                cgImage: finalImage,
                size: NSSize(width: finalImage.width, height: finalImage.height)
            )

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            guard pasteboard.writeObjects([nsImage]) else {
                throw ScreenTranslateError.clipboardWriteFailed
            }

            copySuccessMessage = NSLocalizedString("copy.success.message", comment: "Copied to clipboard")
            clearCopySuccessMessage()
        } catch {
            errorMessage = NSLocalizedString("error.clipboard.write.failed", comment: "Failed to copy to clipboard")
            clearError()
        }

        isCopyingWithTranslations = false
    }

    func clearCopySuccessMessage() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            copySuccessMessage = nil
        }
    }

    func dismissCopySuccessMessage() {
        copySuccessMessage = nil
    }
}
