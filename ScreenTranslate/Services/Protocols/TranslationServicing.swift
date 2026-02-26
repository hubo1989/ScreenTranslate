//
//  TranslationServicing.swift
//  ScreenTranslate
//
//  Protocol abstraction for TranslationService to enable testing
//

import Foundation

/// Protocol for translation service operations.
/// Provides abstraction for testing and dependency injection.
protocol TranslationServicing: Sendable {
    /// Translates segments using the preferred engine with automatic fallback
    /// - Parameters:
    ///   - segments: Source texts to translate
    ///   - targetLanguage: Target language code
    ///   - preferredEngine: User's preferred translation engine
    ///   - sourceLanguage: Source language code (nil for auto-detect)
    /// - Returns: Array of bilingual segments with source and translated text
    func translate(
        segments: [String],
        to targetLanguage: String,
        preferredEngine: EngineIdentifier,
        from sourceLanguage: String?
    ) async throws -> [BilingualSegment]
}

// MARK: - TranslationService Conformance

@available(macOS 13.0, *)
extension TranslationService: TranslationServicing {}
