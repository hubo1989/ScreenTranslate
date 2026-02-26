//
//  TranslationEngineConfig.swift
//  ScreenTranslate
//
//  Configuration model for individual translation engines
//

import Foundation

/// Configuration for a translation engine
struct TranslationEngineConfig: Codable, Identifiable, Equatable, Sendable {
    /// Engine type identifier
    let id: TranslationEngineType

    /// Whether this engine is enabled for use
    var isEnabled: Bool

    /// Engine-specific options
    var options: EngineOptions?

    /// Custom display name (for custom engines)
    var customName: String?

    init(
        id: TranslationEngineType,
        isEnabled: Bool = false,
        options: EngineOptions? = nil,
        customName: String? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.options = options
        self.customName = customName
    }

    /// Default configuration for an engine type
    static func `default`(for type: TranslationEngineType) -> TranslationEngineConfig {
        TranslationEngineConfig(
            id: type,
            isEnabled: type == .apple, // Only Apple enabled by default
            options: EngineOptions.default(for: type)
        )
    }
}

/// Engine-specific configuration options
struct EngineOptions: Codable, Equatable, Sendable {
    /// Custom base URL (for self-hosted or alternative endpoints)
    var baseURL: String?

    /// Model name (for LLM engines)
    var modelName: String?

    /// Request timeout in seconds
    var timeout: TimeInterval?

    /// Maximum tokens for LLM responses
    var maxTokens: Int?

    /// Temperature for LLM responses (0.0-2.0)
    var temperature: Double?

    /// Custom headers for API requests
    var customHeaders: [String: String]?

    init(
        baseURL: String? = nil,
        modelName: String? = nil,
        timeout: TimeInterval? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        customHeaders: [String: String]? = nil
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.timeout = timeout
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.customHeaders = customHeaders
    }

    /// Default options for an engine type
    static func `default`(for type: TranslationEngineType) -> EngineOptions? {
        switch type {
        case .openai:
            return EngineOptions(
                baseURL: type.defaultBaseURL,
                modelName: type.defaultModelName,
                timeout: 30,
                maxTokens: 2048,
                temperature: 0.3
            )
        case .claude:
            return EngineOptions(
                baseURL: type.defaultBaseURL,
                modelName: type.defaultModelName,
                timeout: 30,
                maxTokens: 2048,
                temperature: 0.3
            )
        case .ollama:
            return EngineOptions(
                baseURL: type.defaultBaseURL,
                modelName: type.defaultModelName,
                timeout: 60,
                maxTokens: 2048,
                temperature: 0.3
            )
        case .google:
            return EngineOptions(
                baseURL: type.defaultBaseURL,
                timeout: 30
            )
        case .deepl:
            return EngineOptions(
                baseURL: type.defaultBaseURL,
                timeout: 30
            )
        case .baidu:
            return EngineOptions(
                baseURL: type.defaultBaseURL,
                timeout: 30
            )
        default:
            return nil
        }
    }
}
