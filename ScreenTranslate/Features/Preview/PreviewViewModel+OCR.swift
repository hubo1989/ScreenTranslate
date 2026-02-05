import Foundation
import SwiftUI
import AppKit

extension PreviewViewModel {
    func performOCR() {
        guard !isPerformingOCR else { return }
        isPerformingOCR = true
        ocrTranslationError = nil

        Task {
            await executeOCR()
        }
    }

    func executeOCR() async {
        defer { isPerformingOCR = false }

        do {
            let result = try await ocrService.recognize(
                image,
                languages: [.english, .chineseSimplified]
            )
            ocrResult = result
        } catch {
            ocrTranslationError = "OCR failed: \(error.localizedDescription)"
        }
    }

    func performTranslation() {
        guard !isPerformingTranslation && !isPerformingOCRThenTranslation else { return }

        if !hasOCRResults {
            performOCRThenTranslation()
            return
        }

        guard let ocrResult = ocrResult else { return }
        let textsToTranslate: [String] = ocrResult.observations.map { $0.text }

        guard !textsToTranslate.isEmpty else {
            ocrTranslationError = "No text to translate."
            return
        }

        isPerformingTranslation = true
        ocrTranslationError = nil
        translations = []

        Task {
            await executeTranslation(texts: textsToTranslate)
        }
    }

    func performOCRThenTranslation() {
        guard !isPerformingOCR && !isPerformingOCRThenTranslation else { return }
        isPerformingOCRThenTranslation = true
        ocrTranslationError = nil

        Task {
            do {
                let result = try await ocrService.recognize(
                    image,
                    languages: [.english, .chineseSimplified]
                )
                ocrResult = result

                guard result.hasResults else {
                    ocrTranslationError = NSLocalizedString("error.ocr.no.text", comment: "No text found in image")
                    isPerformingOCRThenTranslation = false
                    return
                }

                let textsToTranslate = result.observations.map { $0.text }
                await executeTranslation(texts: textsToTranslate)
            } catch {
                ocrTranslationError = String(
                    format: NSLocalizedString("error.ocr.failed", comment: "OCR failed"),
                    error.localizedDescription
                )
            }

            isPerformingOCRThenTranslation = false
        }
    }

    func executeTranslation(texts: [String]) async {
        defer { isPerformingTranslation = false }

        var results: [TranslationResult] = []

        let targetLanguage = settings.translationTargetLanguage ?? .english

        for text in texts {
            do {
                let translation = try await translationEngine.translate(
                    text,
                    to: targetLanguage
                )
                results.append(translation)
            } catch {
                results.append(TranslationResult.empty(for: text))
            }
        }

        translations = results

        isTranslationOverlayVisible = true
        showTranslationResult()
    }

    func showTranslationResult() {
    }

    func toggleTranslationOverlay() {
        isTranslationOverlayVisible.toggle()
    }
}
