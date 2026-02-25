//
//  TranslationEngineRegistry.swift
//  ScreenTranslate
//
//  Registry for managing translation engine providers
//

import Foundation
import os.log

/// Actor-based registry for managing translation engine providers
actor TranslationEngineRegistry {
    /// Shared singleton instance
    static let shared = TranslationEngineRegistry()

    /// Registered providers keyed by engine type
    private var providers: [TranslationEngineType: any TranslationProvider] = [:]

    /// Keychain service for credential access
    private let keychain = KeychainService.shared

    /// Logger instance
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "TranslationEngineRegistry"
    )

    private init() {
        // Cannot call async method in init, so we register synchronously
        // Built-in providers don't need async setup
        let appleProvider = AppleTranslationProvider()
        providers[.apple] = appleProvider

        let mtranProvider = MTranServerEngine.shared
        providers[.mtranServer] = mtranProvider

        logger.info("Registered 2 built-in providers")
    }

    // MARK: - Registration

    /// Register a provider for an engine type
    func register(_ provider: any TranslationProvider, for type: TranslationEngineType) {
        providers[type] = provider
        logger.info("Registered provider for \(type.rawValue)")
    }

    /// Unregister a provider for an engine type
    func unregister(_ type: TranslationEngineType) {
        providers.removeValue(forKey: type)
        logger.info("Unregistered provider for \(type.rawValue)")
    }

    /// Get the provider for an engine type
    func provider(for type: TranslationEngineType) -> (any TranslationProvider)? {
        return providers[type]
    }

    // MARK: - Availability

    /// List all registered engine types
    func registeredEngines() -> [TranslationEngineType] {
        Array(providers.keys)
    }

    /// List all available engines (registered and configured)
    func availableEngines() async -> [TranslationEngineType] {
        var available: [TranslationEngineType] = []
        for (type, provider) in providers {
            if await provider.isAvailable {
                available.append(type)
            }
        }
        return available.sorted { $0.rawValue < $1.rawValue }
    }

    /// Check if an engine is configured (has required credentials)
    func isEngineConfigured(_ type: TranslationEngineType) async -> Bool {
        // Built-in engines don't need credentials
        if !type.requiresAPIKey {
            return await providers[type]?.isAvailable ?? false
        }

        // Check if credentials exist in Keychain
        return await keychain.hasCredentials(for: type)
    }

    /// Check if an engine is available for use
    func isEngineAvailable(_ type: TranslationEngineType) async -> Bool {
        guard let provider = providers[type] else { return false }
        return await provider.isAvailable
    }
}

// MARK: - Provider Creation

extension TranslationEngineRegistry {
    /// Create and register a provider for an engine type
    /// This is used for engines that require configuration (LLM, cloud services)
    func createProvider(
        for type: TranslationEngineType,
        config: TranslationEngineConfig
    ) async throws -> any TranslationProvider {
        // Check if already registered
        if let existing = providers[type] {
            return existing
        }

        let provider: any TranslationProvider

        switch type {
        case .apple, .mtranServer:
            // These are registered in init
            throw RegistryError.alreadyRegistered

        case .openai, .claude, .ollama:
            provider = try await LLMTranslationProvider(
                type: type,
                config: config,
                keychain: keychain
            )

        case .google:
            provider = try await GoogleTranslationProvider(
                config: config,
                keychain: keychain
            )

        case .deepl:
            provider = try await DeepLTranslationProvider(
                config: config,
                keychain: keychain
            )

        case .baidu:
            provider = try await BaiduTranslationProvider(
                config: config,
                keychain: keychain
            )

        case .custom:
            provider = try await CompatibleTranslationProvider(
                config: config,
                keychain: keychain
            )
        }

        register(provider, for: type)
        return provider
    }
}

// MARK: - Registry Errors

enum RegistryError: LocalizedError, Sendable {
    case alreadyRegistered
    case notRegistered(TranslationEngineType)
    case configurationMissing(TranslationEngineType)
    case credentialsNotFound(TranslationEngineType)

    var errorDescription: String? {
        switch self {
        case .alreadyRegistered:
            return NSLocalizedString(
                "registry.error.already_registered",
                comment: "Provider is already registered"
            )
        case .notRegistered(let type):
            return String(
                format: NSLocalizedString(
                    "registry.error.not_registered",
                    comment: "No provider registered for %@"
                ),
                type.localizedName
            )
        case .configurationMissing(let type):
            return String(
                format: NSLocalizedString(
                    "registry.error.config_missing",
                    comment: "Configuration missing for %@"
                ),
                type.localizedName
            )
        case .credentialsNotFound(let type):
            return String(
                format: NSLocalizedString(
                    "registry.error.credentials_not_found",
                    comment: "Credentials not found for %@"
                ),
                type.localizedName
            )
        }
    }
}
