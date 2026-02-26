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
        preferredEngine: EngineIdentifier = .standard(.apple),
        fallbackEnabled: Bool = true,
        parallelEngines: [EngineIdentifier] = [],
        sceneBindings: [TranslationScene: SceneEngineBinding] = [:],
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig] = []
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
                scene: scene,
                compatibleConfigs: compatibleConfigs
            )

        case .parallel:
            return try await translateParallel(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                engines: parallelEngines.isEmpty ? [preferredEngine] : parallelEngines,
                scene: scene,
                compatibleConfigs: compatibleConfigs
            )

        case .quickSwitch:
            return try await translateForQuickSwitch(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                primaryEngine: preferredEngine,
                scene: scene,
                compatibleConfigs: compatibleConfigs
            )

        case .sceneBinding:
            return try await translateByScene(
                segments: segments,
                to: targetLanguage,
                from: sourceLanguage,
                scene: scene ?? .screenshot,
                bindings: sceneBindings,
                compatibleConfigs: compatibleConfigs
            )
        }
    }

    // MARK: - Selection Mode Implementations

    /// Primary with fallback mode
    private func translateWithFallback(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        primaryEngine: EngineIdentifier,
        fallbackEnabled: Bool,
        fallbackEngine: EngineIdentifier? = nil,
        scene: TranslationScene?,
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig]
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
                mode: .primaryWithFallback,
                compatibleConfigs: compatibleConfigs
            )
            return result
        } catch {
            errors.append(error)
            logger.warning("Primary engine \(primaryEngine.id) failed: \(error.localizedDescription)")
        }

        // Try fallback if enabled
        if fallbackEnabled {
            let actualFallback: EngineIdentifier
            if let engine = fallbackEngine {
                actualFallback = engine
            } else if let scene = scene {
                let binding = SceneEngineBinding.default(for: scene)
                actualFallback = binding.fallbackEngine.map { .standard($0) } ?? .standard(.mtranServer)
            } else {
                actualFallback = primaryEngine == .standard(.apple) ? .standard(.mtranServer) : .standard(.apple)
            }

            do {
                let result = try await translateWithEngine(
                    actualFallback,
                    segments: segments,
                    to: targetLanguage,
                    from: sourceLanguage,
                    scene: scene,
                    mode: .primaryWithFallback,
                    compatibleConfigs: compatibleConfigs
                )
                logger.info("Fallback to \(actualFallback.id) succeeded")
                return result
            } catch {
                errors.append(error)
                logger.warning("Fallback engine \(actualFallback.id) also failed: \(error.localizedDescription)")
            }
        }

        throw MultiEngineError.allEnginesFailed(errors)
    }

    /// Parallel mode - run multiple engines simultaneously
    private func translateParallel(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        engines: [EngineIdentifier],
        scene: TranslationScene?,
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig]
    ) async throws -> TranslationResultBundle {
        let primaryEngine = engines.first ?? .standard(.apple)

        let results = await withTaskGroup(of: EngineResult.self, returning: [EngineResult].self) { group in
            for engine in engines {
                group.addTask {
                    do {
                        let start = Date()
                        let provider = try await self.registry.getProvider(for: engine, compatibleConfigs: compatibleConfigs)

                        await self.applyPromptConfig(
                            to: provider,
                            identifier: engine,
                            scene: scene,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage
                        )

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
        primaryEngine: EngineIdentifier,
        scene: TranslationScene?,
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig]
    ) async throws -> TranslationResultBundle {
        return try await translateWithEngine(
            primaryEngine,
            segments: segments,
            to: targetLanguage,
            from: sourceLanguage,
            scene: scene,
            mode: .quickSwitch,
            compatibleConfigs: compatibleConfigs
        )
    }

    /// Scene binding mode - use engine binding for specific scene
    private func translateByScene(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        scene: TranslationScene,
        bindings: [TranslationScene: SceneEngineBinding],
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig]
    ) async throws -> TranslationResultBundle {
        let binding = bindings[scene] ?? SceneEngineBinding.default(for: scene)

        let primaryIdentifier: EngineIdentifier = .standard(binding.primaryEngine)
        let fallbackIdentifier: EngineIdentifier? = binding.fallbackEngine.map { .standard($0) }

        return try await translateWithFallback(
            segments: segments,
            to: targetLanguage,
            from: sourceLanguage,
            primaryEngine: primaryIdentifier,
            fallbackEnabled: binding.fallbackEnabled,
            fallbackEngine: fallbackIdentifier,
            scene: scene,
            compatibleConfigs: compatibleConfigs
        )
    }

    /// Translate with a specific engine
    private func translateWithEngine(
        _ identifier: EngineIdentifier,
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        scene: TranslationScene?,
        mode: EngineSelectionMode = .primaryWithFallback,
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig]
    ) async throws -> TranslationResultBundle {
        let start = Date()
        let provider = try await registry.getProvider(for: identifier, compatibleConfigs: compatibleConfigs)

        guard await provider.isAvailable else {
            throw TranslationProviderError.notAvailable
        }

        // Apply custom prompt configuration if available
        await applyPromptConfig(
            to: provider,
            identifier: identifier,
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
            engine: identifier,
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
        identifier: EngineIdentifier,
        scene: TranslationScene?,
        sourceLanguage: String?,
        targetLanguage: String
    ) async {
        guard let llmProvider = provider as? LLMTranslationProvider else { return }

        let sceneToUse = scene ?? .screenshot
        let customPrompt: String

        switch identifier {
        case .standard(let engine):
            customPrompt = promptConfig.promptPreview(
                for: engine,
                scene: sceneToUse,
                compatibleIndex: nil
            )
        case .compatible:
            customPrompt = TranslationPromptConfig.defaultPrompt
        }

        if customPrompt != TranslationPromptConfig.defaultPrompt {
            await llmProvider.setCustomPromptTemplate(customPrompt)
        } else {
            await llmProvider.setCustomPromptTemplate(nil)
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
        preferredEngine: EngineIdentifier = .standard(.apple),
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
    func testConnection(
        for identifier: EngineIdentifier,
        compatibleConfigs: [CompatibleTranslationProvider.CompatibleConfig]
    ) async -> Bool {
        do {
            let provider = try await registry.getProvider(for: identifier, compatibleConfigs: compatibleConfigs)
            return await provider.checkConnection()
        } catch {
            return false
        }
    }
}
