import Foundation

/// A single translation history entry.
/// Contains the source text, translated text, screenshot thumbnail, and metadata.
struct TranslationHistory: Identifiable, Codable, Sendable {
    // MARK: - Types

    /// Coding keys for custom encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case id
        case sourceText
        case translatedText
        case sourceLanguage
        case targetLanguage
        case timestamp
        case thumbnailData
    }

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Original source text
    let sourceText: String

    /// Translated text
    let translatedText: String

    /// Source language name
    let sourceLanguage: String

    /// Target language name
    let targetLanguage: String

    /// When the translation was performed
    let timestamp: Date

    /// JPEG thumbnail data (max 10KB, 128px on longest edge)
    let thumbnailData: Data?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        timestamp: Date = Date(),
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.thumbnailData = thumbnailData
    }

    // MARK: - Computed Properties

    /// A formatted description of the translation
    var description: String {
        "\(sourceLanguage) → \(targetLanguage)"
    }

    /// Whether the history entry has a thumbnail
    var hasThumbnail: Bool {
        thumbnailData != nil && !(thumbnailData?.isEmpty ?? true)
    }

    /// Truncated source text for preview (max 500 characters)
    var sourcePreview: String {
        String(sourceText.prefix(500))
    }

    /// Truncated translated text for preview (max 500 characters)
    var translatedPreview: String {
        String(translatedText.prefix(500))
    }

    /// Whether the source text is longer than preview
    var isSourceTruncated: Bool {
        sourceText.count > 500
    }

    /// Whether the translated text is longer than preview
    var isTranslatedTruncated: Bool {
        translatedText.count > 500
    }

    /// Formatted timestamp string
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Full date string
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Search Match

extension TranslationHistory {
    /// Checks if the history entry matches the search query.
    /// - Parameter query: The search string to match against
    /// - Returns: True if the query is found in source or translated text
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let lowercaseQuery = query.lowercased()
        return sourceText.lowercased().contains(lowercaseQuery) ||
               translatedText.lowercased().contains(lowercaseQuery)
    }
}

// MARK: - Factory from TranslationResult

extension TranslationHistory {
    /// Creates a history entry from a translation result.
    /// - Parameters:
    ///   - result: The translation result to convert
    ///   - thumbnailData: Optional thumbnail data
    /// - Returns: A new TranslationHistory entry
    static func from(
        result: TranslationResult,
        thumbnailData: Data? = nil
    ) -> TranslationHistory {
        TranslationHistory(
            sourceText: result.sourceText,
            translatedText: result.translatedText,
            sourceLanguage: result.sourceLanguage,
            targetLanguage: result.targetLanguage,
            timestamp: result.timestamp,
            thumbnailData: thumbnailData
        )
    }
}
