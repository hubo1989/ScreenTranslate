import Foundation
import Translation
import os.signpost
import os.log

// MARK: - Translation Language (Shared Type)

/// Translation languages supported by Translation framework
/// Defined at module level for use in AppSettings without direct coupling
enum TranslationLanguage: String, CaseIterable, Sendable, Codable {
    case auto = "auto"
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"
    case thai = "th"
    case vietnamese = "vi"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"
    case ukrainian = "uk"
    case czech = "cs"
    case swedish = "sv"
    case danish = "da"
    case finnish = "fi"
    case norwegian = "no"
    case greek = "el"
    case hebrew = "he"
    case indonesian = "id"
    case malay = "ms"
    case romanian = "ro"

    /// The Locale.Language identifier for this language
    var localeLanguage: Locale.Language {
        if self == .auto {
            return Locale.Language(identifier: "en")
        }
        let languageCode = rawValue.components(separatedBy: "-").first ?? rawValue
        return Locale.Language(identifier: languageCode)
    }

    /// Localized display name
    var localizedName: String {
        if self == .auto {
            return NSLocalizedString("translation.auto", comment: "")
        }
        let languageCode = rawValue.components(separatedBy: "-").first ?? rawValue
        return Locale.current.localizedString(forLanguageCode: languageCode) ?? rawValue
    }

    /// BCP 47 language tag
    var bcp47Tag: String {
        rawValue
    }
}

/// Actor responsible for translating text using the Translation framework (macOS 12+).
/// Thread-safe, async translation with support for multiple languages.
@available(macOS 13.0, *)
actor TranslationEngine {
    // MARK: - Performance Logging

    private static let performanceLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenCapture",
        category: .pointsOfInterest
    )

    private static let signpostID = OSSignpostID(log: performanceLog)

    // MARK: - Properties

    /// Shared instance for app-wide translation operations
    static let shared = TranslationEngine()

    /// Whether a translation operation is currently in progress
    private var isProcessing = false

    // MARK: - Configuration

    /// Translation configuration options
    struct Configuration: Sendable {
        /// Target language for translation (nil for system default)
        var targetLanguage: TranslationLanguage?

        /// Request timeout in seconds
        var timeout: TimeInterval

        /// Whether to automatically detect source language
        var autoDetectSourceLanguage: Bool

        static let `default` = Configuration(
            targetLanguage: nil,
            timeout: 10.0,
            autoDetectSourceLanguage: true
        )
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Translates text using the Translation framework.
    /// - Parameters:
    ///   - text: The text to translate
    ///   - config: Translation configuration (uses default if not specified)
    /// - Returns: TranslationResult containing translated text
    /// - Throws: TranslationEngineError if translation fails
    func translate(
        _ text: String,
        config: Configuration = .default
    ) async throws -> TranslationResult {
        // Prevent concurrent translation operations
        guard !isProcessing else {
            throw TranslationEngineError.operationInProgress
        }
        isProcessing = true
        defer { isProcessing = false }

        // Validate input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationEngineError.emptyInput
        }

        // Determine target language (auto means use system default)
        let effectiveTargetLanguage: TranslationLanguage
        if let target = config.targetLanguage, target != .auto {
            effectiveTargetLanguage = target
        } else {
            effectiveTargetLanguage = Self.systemTargetLanguage()
        }

        // Perform translation with signpost for profiling
        os_signpost(.begin, log: Self.performanceLog, name: "Translation", signpostID: Self.signpostID)
        let startTime = CFAbsoluteTimeGetCurrent()

        // Define timeout error type
        struct TranslationTimeout: Error {}

        do {
            // Perform translation with timeout
            let response: TranslationSession.Response = try await withThrowingTaskGroup(
                of: Result<TranslationSession.Response, any Error>.self
            ) { group in
                // Translation task
                group.addTask { [text, effectiveTargetLanguage] in
                    do {
                        let session = TranslationSession(
                            installedSource: effectiveTargetLanguage.localeLanguage,
                            target: nil
                        )
                        let result = try await session.translate(text)
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }

                // Timeout task
                group.addTaskUnlessCancelled { [timeout = config.timeout] in
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    return .failure(TranslationTimeout())
                }

                // Wait for first completed task
                guard let result = try await group.next() else {
                    throw TranslationTimeout()
                }
                group.cancelAll()
                return try result.get()
            }

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            os_signpost(.end, log: Self.performanceLog, name: "Translation", signpostID: Self.signpostID)

            #if DEBUG
            os_log("Translation completed in %.1fms", log: OSLog.default, type: .info, duration)
            #endif

            // Convert response to translated text
            // TranslationSession.Response is a struct that contains the translated text
            let translatedText = String(describing: response)

            return TranslationResult(
                sourceText: text,
                translatedText: translatedText,
                sourceLanguage: NSLocalizedString("translation.auto.detected", comment: ""),
                targetLanguage: effectiveTargetLanguage.localizedName
            )

        } catch is TranslationTimeout {
            os_signpost(.end, log: Self.performanceLog, name: "Translation", signpostID: Self.signpostID)
            throw TranslationEngineError.timeout

        } catch {
            os_signpost(.end, log: Self.performanceLog, name: "Translation", signpostID: Self.signpostID)
            throw TranslationEngineError.translationFailed(underlying: error)
        }
    }

    /// Translates text with automatic language detection.
    /// - Parameter text: The text to translate
    /// - Returns: TranslationResult containing translated text
    /// - Throws: TranslationEngineError if translation fails
    func translate(_ text: String) async throws -> TranslationResult {
        try await translate(text, config: .default)
    }

    /// Translates text to a specific target language.
    /// - Parameters:
    ///   - text: The text to translate
    ///   - targetLanguage: The target translation language
    /// - Returns: TranslationResult containing translated text
    /// - Throws: TranslationEngineError if translation fails
    func translate(
        _ text: String,
        to targetLanguage: TranslationLanguage
    ) async throws -> TranslationResult {
        var config = Configuration.default
        config.targetLanguage = targetLanguage
        return try await translate(text, config: config)
    }

    // MARK: - Private Methods

    /// Returns the system's target language based on user preferences
    private static func systemTargetLanguage() -> TranslationLanguage {
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let systemRegion = Locale.current.language.region?.identifier ?? ""

        let bcp47 = systemRegion.isEmpty ? systemLanguage : "\(systemLanguage)-\(systemRegion)"

        // Find exact match
        if let match = TranslationLanguage(rawValue: bcp47) {
            return match
        }

        // Try language-only match
        if let match = TranslationLanguage.allCases.first(where: { $0.rawValue.hasPrefix(systemLanguage) }) {
            return match
        }

        return .english
    }

    /// Checks if a language pair is supported for translation
    func isLanguagePairSupported(
        source: TranslationLanguage,
        target: TranslationLanguage
    ) -> Bool {
        // Auto is always valid (will use system default)
        guard source != .auto, target != .auto else { return true }

        // Most common pairs are supported; this is a simplified check
        return source != target
    }
}

// MARK: - Translation Engine Errors

/// Errors that can occur during translation operations
enum TranslationEngineError: LocalizedError, Sendable {
    /// Translation operation is already in progress
    case operationInProgress

    /// The input text is empty
    case emptyInput

    /// Translation operation timed out
    case timeout

    /// The requested language pair is not supported
    case unsupportedLanguagePair(source: String, target: String)

    /// Translation failed with an underlying error
    case translationFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return NSLocalizedString("error.translation.in.progress", comment: "")
        case .emptyInput:
            return NSLocalizedString("error.translation.empty.input", comment: "")
        case .timeout:
            return NSLocalizedString("error.translation.timeout", comment: "")
        case .unsupportedLanguagePair(let source, let target):
            return String(format: NSLocalizedString("error.translation.unsupported.pair", comment: ""), source, target)
        case .translationFailed:
            return NSLocalizedString("error.translation.failed", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .operationInProgress:
            return NSLocalizedString("error.translation.in.progress.recovery", comment: "")
        case .emptyInput:
            return NSLocalizedString("error.translation.empty.input.recovery", comment: "")
        case .timeout:
            return NSLocalizedString("error.translation.timeout.recovery", comment: "")
        case .unsupportedLanguagePair:
            return NSLocalizedString("error.translation.unsupported.pair.recovery", comment: "")
        case .translationFailed:
            return NSLocalizedString("error.translation.failed.recovery", comment: "")
        }
    }
}
