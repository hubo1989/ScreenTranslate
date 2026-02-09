//
//  AppleTranslationProvider.swift
//  ScreenTranslate
//
//  Created for US-010: 创建 TranslationService 编排层
//

import Foundation

/// Wrapper around TranslationEngine to conform to TranslationProvider protocol
@available(macOS 13.0, *)
actor AppleTranslationProvider: TranslationProvider {
    nonisolated var id: String { "apple" }
    nonisolated var name: String { "Apple Translation" }
    
    private let engine: TranslationEngine
    
    init(engine: TranslationEngine = .shared) {
        self.engine = engine
    }
    
    var isAvailable: Bool {
        get async { true }
    }
    
    func translate(
        text: String,
        from sourceLanguage: String?,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        guard let target = TranslationLanguage(rawValue: targetLanguage) else {
            throw TranslationProviderError.unsupportedLanguage(targetLanguage)
        }
        
        do {
            return try await engine.translate(text, to: target)
        } catch let error as TranslationEngineError {
            throw mapEngineError(error)
        }
    }
    
    func checkConnection() async -> Bool {
        true
    }
    
    private func mapEngineError(_ error: TranslationEngineError) -> TranslationProviderError {
        switch error {
        case .operationInProgress:
            return .translationFailed("Translation operation already in progress")
        case .emptyInput:
            return .emptyInput
        case .timeout:
            return .timeout
        case .unsupportedLanguagePair(_, let target):
            return .unsupportedLanguage(target)
        case .languageNotInstalled(let language, _):
            return .translationFailed("Language not installed: \(language)")
        case .translationFailed(let underlying):
            return .translationFailed(underlying.localizedDescription)
        }
    }
}
