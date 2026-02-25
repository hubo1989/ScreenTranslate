//
//  TextTranslationFlow.swift
//  ScreenTranslate
//
//  Created for US-003: Create TextTranslationFlow for plain text translation
//

import Foundation
import os.log

/// Flow phase for plain text translation
enum TextTranslationPhase: Sendable, Equatable {
    case idle
    case translating
    case completed
    case failed(TextTranslationError)

    var isProcessing: Bool {
        self == .translating
    }

    var localizedDescription: String {
        switch self {
        case .idle:
            return String(localized: "textTranslation.phase.idle")
        case .translating:
            return String(localized: "textTranslation.phase.translating")
        case .completed:
            return String(localized: "textTranslation.phase.completed")
        case .failed:
            return String(localized: "textTranslation.phase.failed")
        }
    }
}

/// Errors that can occur during text translation
enum TextTranslationError: LocalizedError, Sendable, Equatable {
    /// The input text is empty
    case emptyInput
    /// Translation failed with underlying error
    case translationFailed(String)
    /// The operation was cancelled
    case cancelled
    /// Translation service is not available
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return String(localized: "textTranslation.error.emptyInput")
        case .translationFailed(let message):
            return String(format: NSLocalizedString("textTranslation.error.translationFailed", comment: ""), message)
        case .cancelled:
            return String(localized: "textTranslation.error.cancelled")
        case .serviceUnavailable:
            return String(localized: "textTranslation.error.serviceUnavailable")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyInput:
            return String(localized: "textTranslation.recovery.emptyInput")
        case .translationFailed:
            return String(localized: "textTranslation.recovery.translationFailed")
        case .cancelled:
            return nil
        case .serviceUnavailable:
            return String(localized: "textTranslation.recovery.serviceUnavailable")
        }
    }
}

/// Result of a plain text translation operation
struct TextTranslationResult: Sendable {
    /// The original text that was translated
    let originalText: String
    /// The translated text
    let translatedText: String
    /// Detected or specified source language
    let sourceLanguage: String?
    /// Target language for translation
    let targetLanguage: String
    /// Bilingual segments (single segment for plain text)
    let segments: [BilingualSegment]
    /// Processing time in seconds
    let processingTime: TimeInterval
}

/// Configuration for text translation
struct TextTranslationConfig: Sendable {
    /// Target language code
    let targetLanguage: String
    /// Source language code (nil for auto-detect)
    let sourceLanguage: String?
    /// Preferred translation engine
    let preferredEngine: TranslationEngineType

    /// Default configuration using common settings
    static let `default` = TextTranslationConfig(
        targetLanguage: "zh-Hans",
        sourceLanguage: nil,
        preferredEngine: .apple
    )
}

/// Handles plain text translation without OCR/image analysis.
/// Reuses existing TranslationService for actual translation.
@available(macOS 13.0, *)
actor TextTranslationFlow {

    // MARK: - Properties

    /// Shared instance for convenience
    static let shared = TextTranslationFlow()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "TextTranslationFlow"
    )

    /// Current translation phase
    private(set) var currentPhase: TextTranslationPhase = .idle

    /// Last translation error (if any)
    private(set) var lastError: TextTranslationError?

    /// Last successful translation result
    private(set) var lastResult: TextTranslationResult?

    /// Current translation task (for cancellation)
    private var currentTask: Task<TextTranslationResult, Error>?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Translates plain text with explicit configuration.
    /// - Parameters:
    ///   - text: The text to translate
    ///   - config: Translation configuration
    /// - Returns: TextTranslationResult with translation details
    func translate(
        _ text: String,
        config: TextTranslationConfig
    ) async throws -> TextTranslationResult {
        // Cancel any ongoing translation
        cancel()

        // Validate input
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            currentPhase = .failed(.emptyInput)
            lastError = .emptyInput
            throw TextTranslationError.emptyInput
        }

        currentPhase = .translating
        lastError = nil

        let startTime = Date()

        let task = Task<TextTranslationResult, Error> {
            let effectiveTargetLanguage = config.targetLanguage
            let effectiveSourceLanguage = config.sourceLanguage
            let effectiveEngine = config.preferredEngine

            logger.info("Starting text translation: \(trimmedText.count) chars to \(effectiveTargetLanguage)")

            // Use TranslationService for actual translation
            let bilingualSegments = try await TranslationService.shared.translate(
                segments: [trimmedText],
                to: effectiveTargetLanguage,
                preferredEngine: effectiveEngine,
                from: effectiveSourceLanguage
            )

            guard let firstSegment = bilingualSegments.first else {
                throw TextTranslationError.translationFailed("No translation returned")
            }

            let processingTime = Date().timeIntervalSince(startTime)

            return TextTranslationResult(
                originalText: trimmedText,
                translatedText: firstSegment.translated,
                sourceLanguage: firstSegment.sourceLanguage,
                targetLanguage: firstSegment.targetLanguage,
                segments: bilingualSegments,
                processingTime: processingTime
            )
        }

        currentTask = task

        do {
            let result = try await task.value

            lastResult = result
            currentPhase = .completed
            currentTask = nil

            logger.info("Text translation completed in \(result.processingTime * 1000)ms")

            return result

        } catch is CancellationError {
            currentPhase = .failed(.cancelled)
            lastError = .cancelled
            currentTask = nil
            throw TextTranslationError.cancelled
        } catch let error as TextTranslationError {
            currentPhase = .failed(error)
            lastError = error
            currentTask = nil
            throw error
        } catch {
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            logger.error("Text translation failed: \(errorMessage)")
            let translationError = TextTranslationError.translationFailed(errorMessage)
            currentPhase = .failed(translationError)
            lastError = translationError
            currentTask = nil
            throw translationError
        }
    }

    /// Cancels any ongoing translation operation
    func cancel() {
        currentTask?.cancel()
        currentTask = nil

        if currentPhase == .translating {
            currentPhase = .failed(.cancelled)
            lastError = .cancelled
        }
    }

    /// Resets the flow to idle state
    func reset() {
        cancel()
        currentPhase = .idle
        lastError = nil
        lastResult = nil
    }

    // MARK: - Convenience Methods

    /// Translates text and returns just the translated string.
    /// Useful for quick translations without full result details.
    func translateText(_ text: String, config: TextTranslationConfig = .default) async throws -> String {
        let result = try await translate(text, config: config)
        return result.translatedText
    }

    /// Translates text to a specific target language.
    func translate(
        _ text: String,
        to targetLanguage: String,
        from sourceLanguage: String? = nil,
        preferredEngine: TranslationEngineType = .apple
    ) async throws -> TextTranslationResult {
        let config = TextTranslationConfig(
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
            preferredEngine: preferredEngine
        )
        return try await translate(text, config: config)
    }
}

// MARK: - AppSettings Integration

extension TextTranslationConfig {
    /// Creates a configuration from current AppSettings.
    /// Must be called from @MainActor context.
    @MainActor
    static func fromAppSettings() -> TextTranslationConfig {
        let settings = AppSettings.shared
        let targetLanguage = settings.translationTargetLanguage?.rawValue ?? "zh-Hans"
        let sourceLanguage: String? = settings.translationSourceLanguage == .auto ? nil : settings.translationSourceLanguage.rawValue
        let preferredEngine: TranslationEngineType = switch settings.preferredTranslationEngine {
        case .apple: .apple
        case .mtranServer: .mtranServer
        }

        return TextTranslationConfig(
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
            preferredEngine: preferredEngine
        )
    }

    /// Creates a configuration specifically for translate and insert functionality.
    /// Uses separate language settings from global translation settings.
    /// Must be called from @MainActor context.
    @MainActor
    static func forTranslateAndInsert() -> TextTranslationConfig {
        let settings = AppSettings.shared
        let targetLanguage = settings.translateAndInsertTargetLanguage?.rawValue ?? "zh-Hans"
        let sourceLanguage: String? = settings.translateAndInsertSourceLanguage == .auto ? nil : settings.translateAndInsertSourceLanguage.rawValue
        let preferredEngine: TranslationEngineType = switch settings.preferredTranslationEngine {
        case .apple: .apple
        case .mtranServer: .mtranServer
        }

        #if DEBUG
        print("[TextTranslationConfig] forTranslateAndInsert:")
        print("  - translateAndInsertTargetLanguage: \(String(describing: settings.translateAndInsertTargetLanguage?.rawValue))")
        print("  - resolved targetLanguage: \(targetLanguage)")
        print("  - translateAndInsertSourceLanguage: \(settings.translateAndInsertSourceLanguage.rawValue)")
        print("  - resolved sourceLanguage: \(String(describing: sourceLanguage))")
        print("  - preferredEngine: \(preferredEngine)")
        #endif

        return TextTranslationConfig(
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
            preferredEngine: preferredEngine
        )
    }
}
