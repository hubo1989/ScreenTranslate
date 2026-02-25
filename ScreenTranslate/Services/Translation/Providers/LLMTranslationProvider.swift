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

        // Fallback: return combined result for all texts
        return texts.map { source in
            TranslationResult(
                sourceText: source,
                translatedText: combinedResult.translatedText,
                sourceLanguage: combinedResult.sourceLanguage,
                targetLanguage: combinedResult.targetLanguage
            )
        }
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

    // MARK: - Private Methods

    private func getCredentials() async throws -> StoredCredentials? {
        guard engineType.requiresAPIKey else { return nil }
        return try await keychain.getCredentials(for: engineType)
    }

    private func buildPrompt(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) -> String {
        let source = sourceLanguage ?? "auto-detect"
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
        let baseURL = getBaseURL()
        let modelName = getModelName()

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.options?.timeout ?? 30

        // Set up authentication
        switch engineType {
        case .claude:
            if let apiKey = credentials?.apiKey {
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        case .openai:
            if let apiKey = credentials?.apiKey {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        case .ollama:
            // Ollama doesn't require auth
            break
        default:
            break
        }

        // Build request body
        let body: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": config.options?.temperature ?? 0.3,
            "max_tokens": config.options?.maxTokens ?? 2048
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("API error (\(httpResponse.statusCode)): \(errorMessage)")

            if httpResponse.statusCode == 401 {
                throw TranslationProviderError.invalidConfiguration("Invalid API key")
            } else if httpResponse.statusCode == 429 {
                throw TranslationProviderError.rateLimited(retryAfter: nil)
            }

            throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
        }

        // Parse response
        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslationProviderError.translationFailed("Failed to parse response")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getBaseURL() -> URL {
        if let customURL = config.options?.baseURL {
            return URL(string: customURL) ?? engineType.defaultBaseURL.map { URL(string: $0)! }!
        }
        return URL(string: engineType.defaultBaseURL ?? "https://api.openai.com/v1")!
    }

    private func getModelName() -> String {
        return config.options?.modelName ?? engineType.defaultModelName ?? "gpt-4o-mini"
    }
}
