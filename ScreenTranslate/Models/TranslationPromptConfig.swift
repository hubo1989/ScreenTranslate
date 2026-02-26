//
//  TranslationPromptConfig.swift
//  ScreenTranslate
//
//  Configuration for customizable translation prompts
//

import Foundation

/// Configuration for translation prompts
struct TranslationPromptConfig: Codable, Equatable, Sendable {
    /// Per-engine custom prompts
    var enginePrompts: [TranslationEngineType: String]

    /// Per-compatible-engine custom prompts (keyed by index: 0-4)
    var compatibleEnginePrompts: [Int: String]

    /// Per-scene custom prompts
    var scenePrompts: [TranslationScene: String]

    init(
        enginePrompts: [TranslationEngineType: String] = [:],
        compatibleEnginePrompts: [Int: String] = [:],
        scenePrompts: [TranslationScene: String] = [:]
    ) {
        self.enginePrompts = enginePrompts
        self.compatibleEnginePrompts = compatibleEnginePrompts
        self.scenePrompts = scenePrompts
    }

    /// Default translation prompt
    static let defaultPrompt = """
        Translate the following text from {source_language} to {target_language}.
        Provide only the translation without any explanations or additional text.

        Text to translate:
        {text}
        """

    /// Default prompt for translate and insert scenario
    static let defaultInsertPrompt = """
        Translate the following text from {source_language} to {target_language}.
        The translation will be inserted at the cursor position.
        Provide only the translation without any explanations, formatting, or additional text.
        Keep the translation concise and natural for the target language.

        Text to translate:
        {text}
        """

    /// Resolve the effective prompt for a given engine and scene
    func resolvedPrompt(
        for engine: TranslationEngineType,
        scene: TranslationScene,
        sourceLanguage: String,
        targetLanguage: String,
        text: String
    ) -> String {
        // Priority: scene-specific > engine-specific > default
        let basePrompt: String
        if let scenePrompt = scenePrompts[scene], !scenePrompt.isEmpty {
            basePrompt = scenePrompt
        } else if let enginePrompt = enginePrompts[engine], !enginePrompt.isEmpty {
            basePrompt = enginePrompt
        } else if scene == .translateAndInsert {
            basePrompt = Self.defaultInsertPrompt
        } else {
            basePrompt = Self.defaultPrompt
        }

        // Replace template variables
        return basePrompt
            .replacingOccurrences(of: "{source_language}", with: sourceLanguage)
            .replacingOccurrences(of: "{target_language}", with: targetLanguage)
            .replacingOccurrences(of: "{text}", with: text)
    }

    /// Get prompt preview for a specific context
    func promptPreview(
        for engine: TranslationEngineType,
        scene: TranslationScene
    ) -> String {
        if let scenePrompt = scenePrompts[scene], !scenePrompt.isEmpty {
            return scenePrompt
        }
        if let enginePrompt = enginePrompts[engine], !enginePrompt.isEmpty {
            return enginePrompt
        }
        if scene == .translateAndInsert {
            return Self.defaultInsertPrompt
        }
        return Self.defaultPrompt
    }

    /// Check if there are any custom prompts configured
    var hasCustomPrompts: Bool {
        !enginePrompts.isEmpty || !compatibleEnginePrompts.isEmpty || !scenePrompts.isEmpty
    }

    /// Reset to default prompts
    mutating func reset() {
        enginePrompts.removeAll()
        compatibleEnginePrompts.removeAll()
        scenePrompts.removeAll()
    }
}

// MARK: - Prompt Template Variables

extension TranslationPromptConfig {
    /// Available template variables for prompts
    static let templateVariables: [PromptVariable] = [
        PromptVariable(
            name: "{source_language}",
            description: NSLocalizedString(
                "prompt.variable.source_language",
                comment: "Source language name"
            )
        ),
        PromptVariable(
            name: "{target_language}",
            description: NSLocalizedString(
                "prompt.variable.target_language",
                comment: "Target language name"
            )
        ),
        PromptVariable(
            name: "{text}",
            description: NSLocalizedString(
                "prompt.variable.text",
                comment: "Text to translate"
            )
        )
    ]
}

/// Template variable description
struct PromptVariable: Identifiable, Sendable {
    let name: String
    let description: String

    var id: String { name }
}
