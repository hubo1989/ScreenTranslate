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
    /// Translates segments using the provided routing configuration
    /// - Parameters:
    ///   - segments: Source texts to translate
    ///   - targetLanguage: Target language code
    ///   - preferredEngine: Primary engine for modes that need one
    ///   - sourceLanguage: Source language code (nil for auto-detect)
    ///   - mode: Engine selection mode
    ///   - fallbackEnabled: Whether fallback should be attempted
    ///   - parallelEngines: Engines to run in parallel mode
    ///   - sceneBindings: Scene-specific routing bindings
    /// - Returns: Array of bilingual segments with source and translated text
    func translate(
        segments: [String],
        to targetLanguage: String,
        preferredEngine: TranslationEngineType,
        from sourceLanguage: String?,
        scene: TranslationScene?,
        mode: EngineSelectionMode,
        fallbackEnabled: Bool,
        parallelEngines: [TranslationEngineType],
        sceneBindings: [TranslationScene: SceneEngineBinding]
    ) async throws -> [BilingualSegment]
}

// MARK: - TranslationService Conformance

@available(macOS 13.0, *)
extension TranslationService: TranslationServicing {}
