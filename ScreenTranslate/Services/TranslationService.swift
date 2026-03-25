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
            let effectiveParallelEngines = await filterEnabledEngines(
                parallelEngines.isEmpty ? [preferredEngine] : parallelEngines
            )
            return try await translateParallel(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                engines: effectiveParallelEngines,
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
            let actualFallback: TranslationEngineType
            if let engine = fallbackEngine {
                actualFallback = engine
            } else if let scene = scene {
                actualFallback = SceneEngineBinding.default(for: scene).fallbackEngine ?? .mtranServer
            } else {
                actualFallback = primaryEngine == .apple ? .mtranServer : .apple
            }

            // Skip fallback if the engine is not explicitly enabled in user settings
            let enabledFallbacks = await filterEnabledEngines([actualFallback])
            guard !enabledFallbacks.isEmpty else {
                logger.warning("Fallback engine \(actualFallback.rawValue) is not enabled, skipping")
                throw MultiEngineError.allEnginesFailed(errors)
            }

            do {
                let result = try await translateWithEngine(
                    actualFallback,
                    segments: segments,
                    to: targetLanguage,
                    from: sourceLanguage,
                    scene: scene,
                    mode: .primaryWithFallback
                )
                let failedPrimary = EngineResult.failed(engine: primaryEngine, error: errors[0])
                let mergedResults = [failedPrimary] + result.results
                logger.info("Fallback to \(actualFallback.rawValue) succeeded")
                return TranslationResultBundle(
                    results: mergedResults,
                    primaryEngine: result.primaryEngine,
                    selectionMode: .primaryWithFallback,
                    scene: scene
                )
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
                        let provider = try await self.resolvedProvider(for: engine)

                        let providerResults = try await self.translateWithResolvedPrompt(
                            provider: provider,
                            engine: engine,
                            texts: segments,
                            from: sourceLanguage,
                            to: targetLanguage,
                            scene: scene
                        )
                        let bilingualSegments = providerResults.map { BilingualSegment(from: $0) }

                        // Treat empty results as failure
                        guard !bilingualSegments.isEmpty else {
                            return EngineResult.failed(
                                engine: engine,
                                error: TranslationProviderError.translationFailed(
                                    "\(provider.name) returned no results"
                                )
                            )
                        }

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

        // If all engines failed (no successful results), throw instead of silently returning empty results
        let failedErrors = results.compactMap { $0.error }
        let hasSuccess = results.contains { $0.isSuccess }
        if !hasSuccess {
            throw MultiEngineError.allEnginesFailed(failedErrors)
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
        let provider = try await resolvedProvider(for: engine)

        guard await provider.isAvailable else {
            throw TranslationProviderError.notAvailable
        }

        let results = try await translateWithResolvedPrompt(
            provider: provider,
            engine: engine,
            texts: segments,
            from: sourceLanguage,
            to: targetLanguage,
            scene: scene
        )

        let bilingualSegments = results.map { BilingualSegment(from: $0) }

        // Treat empty results as failure so callers can trigger fallback
        guard !bilingualSegments.isEmpty else {
            throw TranslationProviderError.translationFailed(
                "\(provider.name) returned no results"
            )
        }

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

    private func translateWithResolvedPrompt(
        provider: any TranslationProvider,
        engine: TranslationEngineType,
        texts: [String],
        from sourceLanguage: String?,
        to targetLanguage: String,
        scene: TranslationScene?
    ) async throws -> [TranslationResult] {
        guard let promptConfigurableProvider = provider as? TranslationPromptConfigurable else {
            return try await provider.translate(
                texts: texts,
                from: sourceLanguage,
                to: targetLanguage
            )
        }

        let promptTemplate = await resolvedPromptTemplate(
            for: provider,
            engine: engine,
            scene: scene
        )

        return try await promptConfigurableProvider.translate(
            texts: texts,
            from: sourceLanguage,
            to: targetLanguage,
            promptTemplate: promptTemplate
        )
    }

    private func resolvedPromptTemplate(
        for provider: any TranslationProvider,
        engine: TranslationEngineType,
        scene: TranslationScene?
    ) async -> String? {
        let sceneToUse = scene ?? .screenshot
        let compatiblePromptID = await (provider as? TranslationPromptContextProviding)?.compatiblePromptIdentifier()

        let resolvedPrompt = promptConfig.promptPreview(
            for: engine,
            scene: sceneToUse,
            compatiblePromptID: compatiblePromptID
        )

        if resolvedPrompt == TranslationPromptConfig.defaultPrompt {
            return nil
        }

        return resolvedPrompt
    }

    /// Filters engine list to only include engines that are explicitly enabled in user settings.
    /// Apple is treated as always enabled (it's the default built-in engine).
    private func filterEnabledEngines(_ engines: [TranslationEngineType]) async -> [TranslationEngineType] {
        let configs = await MainActor.run {
            AppSettings.shared.engineConfigs
        }
        return engines.filter { engine in
            engine == .apple || configs[engine]?.isEnabled == true
        }
    }

    private func resolvedProvider(for engine: TranslationEngineType) async throws -> any TranslationProvider {
        if let provider = await registry.provider(for: engine) {
            return provider
        }

        let engineConfig = await MainActor.run {
            AppSettings.shared.engineConfigs[engine] ?? .default(for: engine)
        }

        return try await registry.createProvider(for: engine, config: engineConfig)
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
        from sourceLanguage: String? = nil,
        scene: TranslationScene? = nil,
        mode: EngineSelectionMode = .primaryWithFallback,
        fallbackEnabled: Bool = true,
        parallelEngines: [TranslationEngineType] = [],
        sceneBindings: [TranslationScene: SceneEngineBinding] = [:]
    ) async throws -> [BilingualSegment] {
        guard !segments.isEmpty else { return [] }

        let bundle = try await translate(
            segments: segments,
            to: targetLanguage,
            from: sourceLanguage,
            scene: scene,
            mode: mode,
            preferredEngine: preferredEngine,
            fallbackEnabled: fallbackEnabled,
            parallelEngines: parallelEngines,
            sceneBindings: sceneBindings
        )

        let result = bundle.primaryResult

        // If no engine produced results, propagate the actual errors
        guard !result.isEmpty else {
            if bundle.successfulEngines.isEmpty {
                let errors = bundle.results.compactMap { $0.error }
                throw MultiEngineError.allEnginesFailed(errors)
            }
            throw MultiEngineError.noResults
        }

        return result
    }

    // MARK: - Connection Testing

    /// Test connection to a specific engine
    func testConnection(for engine: TranslationEngineType) async -> Bool {
        // First try to get existing provider
        if let provider = await registry.provider(for: engine) {
            return await provider.checkConnection()
        }

        // If provider doesn't exist, create it for engines that need credentials
        // (Google, DeepL, Baidu, LLM providers, etc.)
        guard engine.requiresAPIKey else {
            // Built-in engines (apple, mtranServer) should already be registered in init
            // If missing, log warning but return true to avoid false failure in UI
            logger.warning("Built-in engine \(engine.rawValue) provider not found in registry")
            return true
        }

        let provider: any TranslationProvider
        do {
            provider = try await resolvedProvider(for: engine)
        } catch {
            logger.error("Failed to resolve provider for \(engine.rawValue): \(error.localizedDescription)")
            return false
        }

        return await provider.checkConnection()
    }
}
