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
}
