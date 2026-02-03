import Foundation
import CoreGraphics

/// Unified OCR engine protocol
/// All OCR engine implementations must conform to this protocol
protocol AnyOCREngine: Sendable {
    /// Performs OCR on a CGImage
    /// - Parameter image: The image to process
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: An error if recognition fails
    func recognize(_ image: CGImage) async throws -> OCRResult
}

/// OCR service that routes to the appropriate engine based on user settings
actor OCRService {
    /// Shared instance
    static let shared = OCRService()

    /// Vision engine (built-in)
    private let visionEngine = OCREngine.shared

    /// PaddleOCR engine (optional)
    private let paddleOCREngine = PaddleOCREngine.shared

    private init() {}

    /// Performs OCR using the currently selected engine
    /// - Parameter image: The image to process
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: An error if recognition fails
    func recognize(_ image: CGImage) async throws -> OCRResult {
        let engineType = await AppSettings.shared.ocrEngine

        switch engineType {
        case .vision:
            return try await visionEngine.recognize(image)
        case .paddleOCR:
            guard await paddleOCREngine.isAvailable else {
                throw OCREngineError.engineNotAvailable
            }
            return try await paddleOCREngine.recognize(image)
        }
    }

    /// Performs OCR with specific languages using the currently selected engine
    /// - Parameters:
    ///   - image: The image to process
    ///   - languages: Set of Vision recognition languages (for Vision engine)
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: An error if recognition fails
    func recognize(
        _ image: CGImage,
        languages: Set<OCREngine.RecognitionLanguage>
    ) async throws -> OCRResult {
        let engineType = await AppSettings.shared.ocrEngine

        switch engineType {
        case .vision:
            return try await visionEngine.recognize(image, languages: languages)
        case .paddleOCR:
            guard await paddleOCREngine.isAvailable else {
                throw OCREngineError.engineNotAvailable
            }
            // Convert Vision languages to PaddleOCR languages
            let paddleLanguages = convertToPaddleOCRLanguages(languages)
            return try await paddleOCREngine.recognize(image, languages: paddleLanguages)
        }
    }

    /// Converts Vision RecognitionLanguage to PaddleOCR Language
    private func convertToPaddleOCRLanguages(
        _ languages: Set<OCREngine.RecognitionLanguage>
    ) -> Set<PaddleOCREngine.Language> {
        var result: Set<PaddleOCREngine.Language> = []

        for language in languages {
            switch language {
            case .chineseSimplified:
                result.insert(.chinese)
                result.insert(.english) // PaddleOCR supports mixed
            case .english:
                result.insert(.english)
            case .french:
                result.insert(.french)
            case .german:
                result.insert(.german)
            case .korean:
                result.insert(.korean)
            case .japanese:
                result.insert(.japanese)
            default:
                // For unsupported languages, fall back to Chinese+English
                result.insert(.chinese)
                result.insert(.english)
            }
        }

        return result.isEmpty ? [.chinese, .english] : result
    }
}
