//
//  VLMProviderType.swift
//  ScreenTranslate
//
//  Created for US-015: VLM and Translation Configuration UI
//

import Foundation

/// VLM (Vision Language Model) provider types supported by the application
enum VLMProviderType: String, CaseIterable, Sendable, Codable, Identifiable {
    case openai = "openai"
    case claude = "claude"
    case ollama = "ollama"
    
    var id: String { rawValue }
    
    /// Localized display name
    var localizedName: String {
        switch self {
        case .openai:
            return NSLocalizedString("vlm.provider.openai", comment: "OpenAI")
        case .claude:
            return NSLocalizedString("vlm.provider.claude", comment: "Claude")
        case .ollama:
            return NSLocalizedString("vlm.provider.ollama", comment: "Ollama")
        }
    }
    
    /// Description of the provider
    var providerDescription: String {
        switch self {
        case .openai:
            return NSLocalizedString(
                "vlm.provider.openai.description",
                comment: "OpenAI GPT-4 Vision API"
            )
        case .claude:
            return NSLocalizedString(
                "vlm.provider.claude.description",
                comment: "Anthropic Claude Vision API"
            )
        case .ollama:
            return NSLocalizedString(
                "vlm.provider.ollama.description",
                comment: "Local Ollama server"
            )
        }
    }
    
    /// Default base URL for this provider
    var defaultBaseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .claude:
            return "https://api.anthropic.com/v1"
        case .ollama:
            return "http://localhost:11434"
        }
    }
    
    /// Default model name for this provider
    var defaultModelName: String {
        switch self {
        case .openai:
            return "gpt-4o"
        case .claude:
            return "claude-sonnet-4-20250514"
        case .ollama:
            return "llava"
        }
    }
    
    /// Whether this provider requires an API key
    var requiresAPIKey: Bool {
        switch self {
        case .openai, .claude:
            return true
        case .ollama:
            return false
        }
    }
}

/// Preferred translation engine type for the translation workflow
enum PreferredTranslationEngine: String, CaseIterable, Sendable, Codable, Identifiable {
    case apple = "apple"
    case mtranServer = "mtran"
    
    var id: String { rawValue }
    
    /// Localized display name
    var localizedName: String {
        switch self {
        case .apple:
            return NSLocalizedString("translation.engine.apple", comment: "Apple Translation")
        case .mtranServer:
            return NSLocalizedString("translation.engine.mtran", comment: "MTransServer")
        }
    }
    
    /// Description of the engine
    var engineDescription: String {
        switch self {
        case .apple:
            return NSLocalizedString(
                "translation.preferred.apple.description",
                comment: "Built-in macOS translation, works offline"
            )
        case .mtranServer:
            return NSLocalizedString(
                "translation.preferred.mtran.description",
                comment: "Self-hosted translation server for better quality"
            )
        }
    }
}
