//
//  TranslationService.swift
//  ScreenTranslate
//
//  Created for US-010: 创建 TranslationService 编排层
//  Updated for multi-engine support
//

import Foundation
import os.log

/// Orchestrates multiple translation providers with various selection modes
@available(macOS 13.0, *)
actor TranslationService {
    static let shared = TranslationService()

    private let registry: TranslationEngineRegistry
    private let keychain = KeychainService.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "TranslationService"
    )

    // Prompt configuration
    private var promptConfig: TranslationPromptConfig = TranslationPromptConfig()

    init(registry: TranslationEngineRegistry = .shared) {
        self.registry = registry
    }

    // MARK: - Main Translation API

    /// Translate text using specified selection mode
    /// - Parameters:
    ///   - segments: Source texts to translate
    ///   - targetLanguage: Target language code
    ///   - sourceLanguage: Source language code (nil for auto-detect)
    ///   - scene: Translation scene (for scene binding mode)
    ///   - mode: Engine selection mode
    ///   - preferredEngine: Primary engine (for modes that need it)
    ///   - fallbackEnabled: Whether to use fallback
    ///   - parallelEngines: Engines to run in parallel mode
    ///   - sceneBindings: Scene-to-engine bindings
    /// - Returns: Bundle with results from all engines
    func translate(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String? = nil,
        scene: TranslationScene? = nil,
        mode: EngineSelectionMode,
        preferredEngine: TranslationEngineType = .apple,
        fallbackEnabled: Bool = true,
        parallelEngines: [TranslationEngineType] = [],
        sceneBindings: [TranslationScene: SceneEngineBinding] = [:]
    ) async throws -> TranslationResultBundle {
        guard !segments.isEmpty else {
            return TranslationResultBundle(
                results: [],
                primaryEngine: preferredEngine,
                selectionMode: mode,
                scene: scene
            )
        }

        switch mode {
        case .primaryWithFallback:
            return try await translateWithFallback(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                primaryEngine: preferredEngine,
                fallbackEnabled: fallbackEnabled,
                scene: scene
            )

        case .parallel:
            return try await translateParallel(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                engines: parallelEngines.isEmpty ? [preferredEngine] : parallelEngines,
                scene: scene
            )

        case .quickSwitch:
            return try await translateForQuickSwitch(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                primaryEngine: preferredEngine,
                scene: scene
            )

        case .sceneBinding:
            return try await translateByScene(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                scene: scene ?? .screenshot,
                bindings: sceneBindings,
                preferredEngine: preferredEngine
            )
        }
    }

    // MARK: - Selection Mode Implementations

    /// Primary with fallback mode
    private func translateWithFallback(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        primaryEngine: TranslationEngineType,
        fallbackEnabled: Bool,
        fallbackEngine: TranslationEngineType? = nil,
        scene: TranslationScene?
    ) async throws -> TranslationResultBundle {
        var errors: [Error] = []

        // Try primary engine
        do {
            let result = try await translateWithEngine(
                primaryEngine,
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                scene: scene,
                mode: .primaryWithFallback
            )
            return result
        } catch {
            errors.append(error)
            logger.warning("Primary engine \(primaryEngine.rawValue) failed: \(error.localizedDescription)")
        }

        // Try fallback if enabled
        if fallbackEnabled {
            // Use provided fallback engine, or default to alternating between apple and mtranServer
            let actualFallback = fallbackEngine ?? (primaryEngine == .apple ? TranslationEngineType.mtranServer : TranslationEngineType.apple)
            do {
                let result = try await translateWithEngine(
                    actualFallback,
                    segments: segments,
                    to: targetLanguage,
                    from: sourceLanguage,
                    scene: scene,
                    mode: .primaryWithFallback
                )
                logger.info("Fallback to \(actualFallback.rawValue) succeeded")
                return result
            } catch {
                errors.append(error)
                logger.warning("Fallback engine \(actualFallback.rawValue) also failed: \(error.localizedDescription)")
            }
        }

        throw MultiEngineError.allEnginesFailed(errors)
    }

    /// Parallel mode - run multiple engines simultaneously
    private func translateParallel(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        engines: [TranslationEngineType],
        scene: TranslationScene?
    ) async throws -> TranslationResultBundle {
        let primaryEngine = engines.first ?? .apple

        let results = await withTaskGroup(of: EngineResult.self, returning: [EngineResult].self) { group in
            for engine in engines {
                group.addTask {
                    do {
                        let start = Date()
                        guard let provider = await self.registry.provider(for: engine) else {
                            return EngineResult.failed(
                                engine: engine,
                                error: RegistryError.notRegistered(engine),
                                latency: 0
                            )
                        }
                        let providerResults = try await provider.translate(
                            texts: segments,
                            from: sourceLanguage,
                            to: targetLanguage
                        )
                        let bilingualSegments = providerResults.map { BilingualSegment(from: $0) }
                        return EngineResult(
                            engine: engine,
                            segments: bilingualSegments,
                            latency: Date().timeIntervalSince(start)
                        )
                    } catch {
                        return EngineResult.failed(engine: engine, error: error)
                    }
                }
            }

            var collectedResults: [EngineResult] = []
            for await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }

        return TranslationResultBundle(
            results: results,
            primaryEngine: primaryEngine,
            selectionMode: .parallel,
            scene: scene
        )
    }

    /// Quick switch mode - start with primary, others load on demand
    private func translateForQuickSwitch(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        primaryEngine: TranslationEngineType,
        scene: TranslationScene?
    ) async throws -> TranslationResultBundle {
        // For now, behaves like primary without fallback
        // UI layer will handle switching to other engines
        return try await translateWithEngine(
            primaryEngine,
            segments: segments,
            to: targetLanguage,
            from: sourceLanguage,
            scene: scene,
            mode: .quickSwitch
        )
    }

    /// Scene binding mode - use engine configured for the scene
    private func translateByScene(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        scene: TranslationScene,
        bindings: [TranslationScene: SceneEngineBinding],
        preferredEngine: TranslationEngineType
    ) async throws -> TranslationResultBundle {
        let binding = bindings[scene] ?? SceneEngineBinding.default(for: scene)

        return try await translateWithFallback(
            segments: segments,
            to: targetLanguage,
            from: sourceLanguage,
            primaryEngine: binding.primaryEngine,
            fallbackEnabled: binding.fallbackEnabled,
            fallbackEngine: binding.fallbackEngine,
            scene: scene
        )
    }

    // MARK: - Helper Methods

    /// Translate with a specific engine
    private func translateWithEngine(
        _ engine: TranslationEngineType,
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        scene: TranslationScene?,
        mode: EngineSelectionMode = .primaryWithFallback
    ) async throws -> TranslationResultBundle {
        let start = Date()

        guard let provider = await registry.provider(for: engine) else {
            throw RegistryError.notRegistered(engine)
        }

        guard await provider.isAvailable else {
            throw TranslationProviderError.notAvailable
        }

        // Apply custom prompt configuration if available
        applyPromptConfig(
            to: provider,
            engine: engine,
            scene: scene,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        let results = try await provider.translate(
            texts: segments,
            from: sourceLanguage,
            to: targetLanguage
        )

        let bilingualSegments = results.map { BilingualSegment(from: $0) }
        let latency = Date().timeIntervalSince(start)

        return TranslationResultBundle.single(
            engine: engine,
            segments: bilingualSegments,
            latency: latency,
            selectionMode: mode,
            scene: scene
        )
    }

    /// Update prompt configuration
    func updatePromptConfig(_ config: TranslationPromptConfig) {
        self.promptConfig = config
    }

    /// Get current prompt configuration
    func getPromptConfig() -> TranslationPromptConfig {
        return promptConfig
    }

    /// Apply prompt configuration to a provider if supported
    private func applyPromptConfig(
        to provider: any TranslationProvider,
        engine: TranslationEngineType,
        scene: TranslationScene?,
        sourceLanguage: String?,
        targetLanguage: String
    ) {
        // Only LLM providers support custom prompts
        guard let llmProvider = provider as? LLMTranslationProvider else { return }

        let sceneToUse = scene ?? .screenshot
        let sourceLang = sourceLanguage ?? "auto"

        // Get custom prompt for this engine and scene
        let customPrompt = promptConfig.promptPreview(
            for: engine,
            scene: sceneToUse,
            compatibleIndex: nil
        )

        // Only apply if it's different from default
        if customPrompt != TranslationPromptConfig.defaultPrompt {
            Task {
                await llmProvider.setCustomPromptTemplate(customPrompt)
            }
        }
    }

    // MARK: - Legacy API (Backward Compatible)

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

        let bundle = try await translate(
            segments: segments,
            to: targetLanguage,
            from: sourceLanguage,
            mode: .primaryWithFallback,
            preferredEngine: preferredEngine
        )

        return bundle.primaryResult
    }

    // MARK: - Connection Testing

    /// Test connection to a specific engine
    func testConnection(for engine: TranslationEngineType) async -> Bool {
        guard let provider = await registry.provider(for: engine) else {
            return false
        }
        return await provider.checkConnection()
    }
}
