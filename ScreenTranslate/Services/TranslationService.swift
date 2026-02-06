//
//  TranslationService.swift
//  ScreenTranslate
//
//  Created for US-010: 创建 TranslationService 编排层
//

import Foundation
import os.log

/// Orchestrates multiple translation providers with fallback logic
@available(macOS 13.0, *)
actor TranslationService {
    static let shared = TranslationService()
    
    private let appleProvider: AppleTranslationProvider
    private let mtranServerProvider: MTranServerEngine
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate", category: "TranslationService")
    
    init(
        appleProvider: AppleTranslationProvider = AppleTranslationProvider(),
        mtranServerProvider: MTranServerEngine = .shared
    ) {
        self.appleProvider = appleProvider
        self.mtranServerProvider = mtranServerProvider
    }
    
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
        preferredEngine: TranslationEngineType = .apple,
        from sourceLanguage: String? = nil
    ) async throws -> [BilingualSegment] {
        guard !segments.isEmpty else { return [] }
        
        let (primary, fallback) = resolveProviders(for: preferredEngine)
        
        do {
            if await primary.isAvailable {
                return try await translateWithProvider(
                    primary,
                    segments: segments,
                    to: targetLanguage,
                    from: sourceLanguage
                )
            }
        } catch {
            logger.warning("Primary provider \(primary.name) failed: \(error.localizedDescription)")
        }
        
        if let fallback = fallback {
            do {
                if await fallback.isAvailable {
                    logger.info("Falling back to \(fallback.name)")
                    return try await translateWithProvider(
                        fallback,
                        segments: segments,
                        to: targetLanguage,
                        from: sourceLanguage
                    )
                }
            } catch {
                logger.error("Fallback provider \(fallback.name) also failed: \(error.localizedDescription)")
                throw error
            }
        }
        
        throw TranslationProviderError.notAvailable
    }
    
    private func resolveProviders(
        for engineType: TranslationEngineType
    ) -> (primary: any TranslationProvider, fallback: (any TranslationProvider)?) {
        switch engineType {
        case .apple:
            return (appleProvider, mtranServerProvider)
        case .mtranServer:
            return (mtranServerProvider, appleProvider)
        }
    }
    
    private func translateWithProvider(
        _ provider: any TranslationProvider,
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?
    ) async throws -> [BilingualSegment] {
        let results = try await provider.translate(
            texts: segments,
            from: sourceLanguage,
            to: targetLanguage
        )
        return results.map { BilingualSegment(from: $0) }
    }
}
