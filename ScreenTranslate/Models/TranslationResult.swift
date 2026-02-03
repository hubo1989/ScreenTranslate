import Foundation

/// The result of a translation operation.
/// Contains the original text, translated text, and language information.
struct TranslationResult: Sendable {
    /// The original source text
    let sourceText: String

    /// The translated text
    let translatedText: String

    /// The source language name (e.g., "English", "Chinese (Simplified)")
    let sourceLanguage: String

    /// The target language name (e.g., "Spanish", "Japanese")
    let targetLanguage: String

    /// When the translation was performed
    let timestamp: Date

    /// Initialize with translation data
    init(
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        timestamp: Date = Date()
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
    }

    /// A formatted description of the translation
    var description: String {
        "\(sourceLanguage) → \(targetLanguage)"
    }

    /// Whether the translation is different from the source
    var hasChanges: Bool {
        sourceText != translatedText
    }
}

// MARK: - Empty Result

extension TranslationResult {
    /// Creates an empty translation result (no-op translation)
    static func empty(for text: String) -> TranslationResult {
        TranslationResult(
            sourceText: text,
            translatedText: text,
            sourceLanguage: NSLocalizedString("translation.unknown", comment: ""),
            targetLanguage: NSLocalizedString("translation.unknown", comment: "")
        )
    }
}

// MARK: - Batch Translation

extension TranslationResult {
    /// Combines multiple translation results into a single result
    static func combine(_ results: [TranslationResult]) -> TranslationResult? {
        guard let first = results.first else { return nil }

        let combinedSource = results.map(\.sourceText).joined(separator: "\n")
        let combinedTranslated = results.map(\.translatedText).joined(separator: "\n")

        return TranslationResult(
            sourceText: combinedSource,
            translatedText: combinedTranslated,
            sourceLanguage: first.sourceLanguage,
            targetLanguage: first.targetLanguage,
            timestamp: first.timestamp
        )
    }
}
