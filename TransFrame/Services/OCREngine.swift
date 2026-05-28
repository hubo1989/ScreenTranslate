import Foundation
import Vision
import CoreGraphics
import os.signpost
import os.log

/// Actor responsible for performing OCR on images using the Vision framework.
/// Thread-safe, async text recognition with support for multiple languages.
actor OCREngine {
    // MARK: - Performance Logging

    private static let performanceLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenCapture",
        category: .pointsOfInterest
    )

    private static let signpostID = OSSignpostID(log: performanceLog)

    // MARK: - Properties

    /// Shared instance for app-wide OCR operations
    static let shared = OCREngine()

    /// Supported recognition languages
    private var supportedLanguages: Set<RecognitionLanguage> = []

    /// Whether an OCR operation is currently in progress
    private var isProcessing = false

    // MARK: - Recognition Language

    /// Text recognition languages supported by Vision framework
    enum RecognitionLanguage: String, CaseIterable, Sendable {
        case english = "en-US"
        case chineseSimplified = "zh-Hans"
        case chineseTraditional = "zh-Hant"
        case japanese = "ja-JP"
        case korean = "ko-KR"
        case french = "fr-FR"
        case german = "de-DE"
        case spanish = "es-ES"
        case italian = "it-IT"
        case portuguese = "pt-BR"
        case russian = "ru-RU"
        case arabic = "ar"
        case hindi = "hi-IN"
        case thai = "th-TH"
        case vietnamese = "vi-VN"

        /// The VNRecognizeTextRequest revision for this language
        var visionLanguage: String {
            rawValue
        }

        /// Localized display name
        var localizedName: String {
            switch self {
            case .english: return NSLocalizedString("lang.english", comment: "")
            case .chineseSimplified: return NSLocalizedString("lang.chinese.simplified", comment: "")
            case .chineseTraditional: return NSLocalizedString("lang.chinese.traditional", comment: "")
            case .japanese: return NSLocalizedString("lang.japanese", comment: "")
            case .korean: return NSLocalizedString("lang.korean", comment: "")
            case .french: return NSLocalizedString("lang.french", comment: "")
            case .german: return NSLocalizedString("lang.german", comment: "")
            case .spanish: return NSLocalizedString("lang.spanish", comment: "")
            case .italian: return NSLocalizedString("lang.italian", comment: "")
            case .portuguese: return NSLocalizedString("lang.portuguese", comment: "")
            case .russian: return NSLocalizedString("lang.russian", comment: "")
            case .arabic: return NSLocalizedString("lang.arabic", comment: "")
            case .hindi: return NSLocalizedString("lang.hindi", comment: "")
            case .thai: return NSLocalizedString("lang.thai", comment: "")
            case .vietnamese: return NSLocalizedString("lang.vietnamese", comment: "")
            }
        }
    }

    // MARK: - Configuration

    /// OCR configuration options
    struct Configuration: Sendable {
        /// Recognition languages (empty for auto-detection)
        var languages: Set<RecognitionLanguage>

        /// Minimum confidence threshold (0.0 to 1.0)
        var minimumConfidence: Float

        /// Whether to use automatic language detection
        var useAutoLanguageDetection: Bool

        /// Recognition level (higher = more accurate but slower)
        var recognitionLevel: RecognitionLevel

        /// Whether to prioritize speed over accuracy
        var prefersFastRecognition: Bool

        static let `default` = Configuration(
            languages: [],
            minimumConfidence: 0.0,
            useAutoLanguageDetection: true,
            recognitionLevel: .accurate,
            prefersFastRecognition: false
        )
    }

    /// Recognition accuracy level
    enum RecognitionLevel: Sendable {
        case fast
        case accurate

        var visionLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .fast: return .fast
            case .accurate: return .accurate
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Performs OCR on a CGImage with the specified configuration.
    /// - Parameters:
    ///   - image: The image to process
    ///   - config: OCR configuration (uses default if not specified)
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: OCRError if recognition fails
    func recognize(
        _ image: CGImage,
        config: Configuration = .default
    ) async throws -> OCRResult {
        // Prevent concurrent OCR operations
        guard !isProcessing else {
            throw OCREngineError.operationInProgress
        }
        isProcessing = true
        defer { isProcessing = false }

        // Validate image
        guard image.width > 0 && image.height > 0 else {
            throw OCREngineError.invalidImage
        }

        let imageSize = CGSize(width: image.width, height: image.height)

        // Create the request
        let request = createRecognitionRequest(config: config)

        // Perform recognition with signpost for profiling
        os_signpost(.begin, log: Self.performanceLog, name: "OCRRecognition", signpostID: Self.signpostID)
        let startTime = CFAbsoluteTimeGetCurrent()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            os_signpost(.end, log: Self.performanceLog, name: "OCRRecognition", signpostID: Self.signpostID)
            throw OCREngineError.recognitionFailed(underlying: error)
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        os_signpost(.end, log: Self.performanceLog, name: "OCRRecognition", signpostID: Self.signpostID)

        #if DEBUG
        os_log("OCR recognition completed in %.1fms", log: OSLog.default, type: .info, duration)
        #endif

        // Extract results
        guard let observations = request.results else {
            return OCRResult.empty(imageSize: imageSize)
        }

        // Convert to OCRText
        let texts = observations.compactMap { obs in
            OCRText.from(obs, imageSize: imageSize)
        }

        // Filter by confidence
        let filteredTexts = texts.filter { $0.confidence >= config.minimumConfidence }

        return OCRResult(
            observations: filteredTexts,
            imageSize: imageSize
        )
    }

    /// Performs OCR on a CGImage with automatic language detection.
    /// - Parameter image: The image to process
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: OCRError if recognition fails
    func recognize(_ image: CGImage) async throws -> OCRResult {
        try await recognize(image, config: .default)
    }

    /// Performs OCR with specific languages.
    /// - Parameters:
    ///   - image: The image to process
    ///   - languages: Set of languages to recognize
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: OCRError if recognition fails
    func recognize(
        _ image: CGImage,
        languages: Set<RecognitionLanguage>
    ) async throws -> OCRResult {
        var config = Configuration.default
        config.languages = languages
        config.useAutoLanguageDetection = languages.isEmpty
        return try await recognize(image, config: config)
    }

    // MARK: - Language Detection

    /// Detects the primary language in an image.
    /// - Parameter image: The image to analyze
    /// - Returns: Detected language, or nil if detection failed
    func detectLanguage(in image: CGImage) async -> RecognitionLanguage? {
        // Try each language and return the one with the best results
        let languagesToTest: [RecognitionLanguage] = [
            .english,
            .chineseSimplified,
            .chineseTraditional,
            .japanese,
            .korean
        ]

        var bestLanguage: RecognitionLanguage?
        var bestConfidence: Float = 0.0

        for language in languagesToTest {
            do {
                var config = Configuration.default
                config.languages = [language]
                config.useAutoLanguageDetection = false
                config.recognitionLevel = .fast
                config.prefersFastRecognition = true
                config.minimumConfidence = 0.3

                let result = try await recognize(image, config: config)

                if result.hasResults {
                    let avgConfidence = result.observations
                        .map(\.confidence)
                        .reduce(0, +) / Float(result.observations.count)

                    if avgConfidence > bestConfidence {
                        bestConfidence = avgConfidence
                        bestLanguage = language
                    }
                }
            } catch {
                // Try next language
                continue
            }
        }

        return bestLanguage
    }

    // MARK: - Private Methods

    /// Creates a configured VNRecognizeTextRequest
    private func createRecognitionRequest(config: Configuration) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest { _, _ in }

        // Set recognition level
        request.recognitionLevel = config.recognitionLevel.visionLevel

        // Enable automatic language detection if requested
        if config.useAutoLanguageDetection {
            request.usesLanguageCorrection = true
        } else {
            // Set specific languages
            request.recognitionLanguages = Array(config.languages).map(\.visionLanguage)
        }

        // Enable text recognition for non-horizontal text
        request.usesLanguageCorrection = true

        return request
    }
}

// MARK: - OCR Engine Errors

/// Errors that can occur during OCR operations
enum OCREngineError: LocalizedError, Sendable {
    /// OCR operation is already in progress
    case operationInProgress

    /// The provided image is invalid or empty
    case invalidImage

    /// Text recognition failed with an underlying error
    case recognitionFailed(underlying: any Error)

    /// No languages are available for recognition
    case noLanguagesAvailable

    /// The selected OCR engine is not available
    case engineNotAvailable

    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return NSLocalizedString("error.ocr.in.progress", comment: "")
        case .invalidImage:
            return NSLocalizedString("error.ocr.invalid.image", comment: "")
        case .recognitionFailed:
            return NSLocalizedString("error.ocr.recognition.failed", comment: "")
        case .noLanguagesAvailable:
            return NSLocalizedString("error.ocr.no.languages", comment: "")
        case .engineNotAvailable:
            return NSLocalizedString("error.ocr.engine.not.available", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .operationInProgress:
            return NSLocalizedString("error.ocr.in.progress.recovery", comment: "")
        case .invalidImage:
            return NSLocalizedString("error.ocr.invalid.image.recovery", comment: "")
        case .recognitionFailed:
            return NSLocalizedString("error.ocr.recognition.failed.recovery", comment: "")
        case .noLanguagesAvailable:
            return NSLocalizedString("error.ocr.no.languages.recovery", comment: "")
        case .engineNotAvailable:
            return NSLocalizedString("error.ocr.engine.not.available.recovery", comment: "")
        }
    }
}
