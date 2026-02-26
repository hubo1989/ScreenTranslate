//
//  LLMTranslationProvider.swift
//  ScreenTranslate
//
//  LLM-based translation provider for OpenAI, Claude, and Ollama
//

import Foundation
import os.log

/// LLM-based translation provider supporting OpenAI, Claude, and Ollama
actor LLMTranslationProvider: TranslationProvider {
    // MARK: - Properties

    nonisolated let id: String
    nonisolated let name: String
    let engineType: TranslationEngineType
    let config: TranslationEngineConfig

    private let keychain: KeychainService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "LLMTranslationProvider"
    )

    // Custom prompt template (nil = use default)
    private var customPromptTemplate: String?

    // MARK: - Initialization

    init(
        type: TranslationEngineType,
        config: TranslationEngineConfig,
        keychain: KeychainService
    ) async throws {
        self.engineType = type
        self.id = type.rawValue
        self.config = config
        self.keychain = keychain

        switch type {
        case .openai:
            self.name = "OpenAI Translation"
        case .claude:
            self.name = "Claude Translation"
        case .gemini:
            self.name = "Gemini Translation"
        case .ollama:
            self.name = "Ollama Translation"
        default:
            throw TranslationProviderError.invalidConfiguration("Invalid LLM type: \(type.rawValue)")
        }
    }

    // MARK: - TranslationProvider Protocol

    var isAvailable: Bool {
        get async {
            // Ollama doesn't need API key
            if engineType == .ollama {
                return true
            }
            // Check for API key in keychain
            return await keychain.hasCredentials(for: engineType)
        }
    }

    func translate(
        text: String,
        from sourceLanguage: String?,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        guard !text.isEmpty else {
            throw TranslationProviderError.emptyInput
        }

        let credentials = try await getCredentials()
        let prompt = buildPrompt(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        let start = Date()
        let translatedText = try await callLLMAPI(
            prompt: prompt,
            credentials: credentials
        )
        let latency = Date().timeIntervalSince(start)

        logger.info("Translation completed in \(latency)s")

        return TranslationResult(
            sourceText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage ?? "Auto",
            targetLanguage: targetLanguage
        )
    }

    func translate(
        texts: [String],
        from sourceLanguage: String?,
        to targetLanguage: String
    ) async throws -> [TranslationResult] {
        guard !texts.isEmpty else { return [] }

        // For multiple texts, combine into single request for efficiency
        let combinedText = texts.joined(separator: "\n---\n")
        let combinedResult = try await translate(
            text: combinedText,
            from: sourceLanguage,
            to: targetLanguage
        )

        // Split the combined result back into individual results
        let translatedTexts = combinedResult.translatedText.components(separatedBy: "\n---\n")

        // Handle case where split doesn't match
        if translatedTexts.count == texts.count {
            return zip(texts, translatedTexts).map { source, translated in
                TranslationResult(
                    sourceText: source,
                    translatedText: translated.trimmingCharacters(in: .whitespacesAndNewlines),
                    sourceLanguage: combinedResult.sourceLanguage,
                    targetLanguage: combinedResult.targetLanguage
                )
            }
        }

        // Split failed - translate individually to ensure correct mapping
        logger.warning("Batch split failed, falling back to individual translations")
        var results: [TranslationResult] = []
        results.reserveCapacity(texts.count)
        for text in texts {
            let result = try await translate(
                text: text,
                from: sourceLanguage,
                to: targetLanguage
            )
            results.append(result)
        }
        return results
    }

    func checkConnection() async -> Bool {
        do {
            // Try a minimal translation to check connection
            let _ = try await translate(
                text: "Hello",
                from: "en",
                to: "zh"
            )
            return true
        } catch {
            logger.error("Connection check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Custom Prompt

    /// Set a custom prompt template for this provider
    /// - Parameter template: The prompt template with {source_language}, {target_language}, {text} placeholders
    func setCustomPromptTemplate(_ template: String?) {
        self.customPromptTemplate = template
    }

    // MARK: - Private Methods

    private func getCredentials() async throws -> StoredCredentials? {
        guard engineType.requiresAPIKey else { return nil }
        guard let credentials = try await keychain.getCredentials(for: engineType) else {
            throw TranslationProviderError.invalidConfiguration("API key required for \(engineType.rawValue)")
        }
        return credentials
    }

    private func buildPrompt(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) -> String {
        let source = sourceLanguage ?? "auto-detect"

        // Use custom template if available
        if let template = customPromptTemplate {
            return template
                .replacingOccurrences(of: "{source_language}", with: source)
                .replacingOccurrences(of: "{target_language}", with: targetLanguage)
                .replacingOccurrences(of: "{text}", with: text)
        }

        // Default prompt
        return """
            Translate the following text from \(source) to \(targetLanguage).
            Provide ONLY the translated text without any explanations, notes, or formatting.

            Text to translate:
            \(text)
            """
    }

    private func callLLMAPI(
        prompt: String,
        credentials: StoredCredentials?
    ) async throws -> String {
        let baseURL = try getBaseURL()
        let modelName = getModelName()

        // Build endpoint and headers based on engine type
        let endpoint: URL
        var headers: [String: String] = ["Content-Type": "application/json"]

        switch engineType {
        case .claude:
            // Claude uses /v1/messages endpoint
            endpoint = baseURL.appendingPathComponent("v1/messages")
            if let apiKey = credentials?.apiKey {
                headers["x-api-key"] = apiKey
                headers["anthropic-version"] = "2023-06-01"
            }
        default:
            // OpenAI, Gemini, Ollama use /chat/completions endpoint
            endpoint = baseURL.appendingPathComponent("chat/completions")
            if let apiKey = credentials?.apiKey {
                headers["Authorization"] = "Bearer \(apiKey)"
            }
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = config.options?.timeout ?? 30
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Build request body based on engine type
        let body: [String: Any]
        switch engineType {
        case .claude:
            // Claude API format
            body = [
                "model": modelName,
                "max_tokens": config.options?.maxTokens ?? 2048,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]
        default:
            // OpenAI/Gemini/Ollama format
            body = [
                "model": modelName,
                "messages": [
                    ["role": "user", "content": prompt]
                ],
                "temperature": config.options?.temperature ?? 0.3,
                "max_tokens": config.options?.maxTokens ?? 2048
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            // Log status code only to avoid exposing user text in logs
            logger.error("API error status=\(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw TranslationProviderError.invalidConfiguration("Invalid API key")
            } else if httpResponse.statusCode == 429 {
                throw TranslationProviderError.rateLimited(retryAfter: nil)
            }

            throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
        }

        // Parse response based on engine type
        return try parseResponse(data, for: engineType)
    }

    private func parseResponse(_ data: Data, for engineType: TranslationEngineType) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.translationFailed("Failed to parse response")
        }

        let content: String?

        switch engineType {
        case .claude:
            content = (json["content"] as? [[String: Any]])?
                .first?["text"] as? String
        default:
            content = ((json["choices"] as? [[String: Any]])?
                .first?["message"] as? [String: Any])?["content"] as? String
        }

        guard let text = content else {
            throw TranslationProviderError.translationFailed("Failed to parse response")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getBaseURL() throws -> URL {
        // First try custom URL from config
        if let customURL = config.options?.baseURL,
           let url = URL(string: customURL) {
            return url
        }

        // Fall back to engine default
        if let defaultURL = engineType.defaultBaseURL,
           let url = URL(string: defaultURL) {
            return url
        }

        // Final fallback
        guard let url = URL(string: "https://api.openai.com/v1") else {
            throw TranslationProviderError.invalidConfiguration("Failed to create API URL")
        }
        return url
    }

    private func getModelName() -> String {
        return config.options?.modelName ?? engineType.defaultModelName ?? "gpt-4o-mini"
    }
}
