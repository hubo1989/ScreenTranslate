//
//  CompatibleTranslationProvider.swift
//  ScreenTranslate
//
//  OpenAI-compatible custom translation provider
//

import Foundation
import os.log

/// OpenAI-compatible translation provider for custom endpoints
actor CompatibleTranslationProvider: TranslationProvider {
    // MARK: - Properties

    nonisolated let id: String
    nonisolated let name: String
    nonisolated let configHash: Int

    private let config: TranslationEngineConfig
    private let compatibleConfig: CompatibleConfig
    private let instanceIndex: Int
    private let keychain: KeychainService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "CompatibleTranslationProvider"
    )

    // MARK: - Configuration

    struct CompatibleConfig: Codable, Equatable, Sendable, Identifiable {
        var id: UUID
        var displayName: String
        var baseURL: String
        var modelName: String
        var hasAPIKey: Bool

        init(
            id: UUID = UUID(),
            displayName: String,
            baseURL: String,
            modelName: String,
            hasAPIKey: Bool = true
        ) {
            self.id = id
            self.displayName = displayName
            self.baseURL = baseURL
            self.modelName = modelName
            self.hasAPIKey = hasAPIKey
        }

        static var `default`: CompatibleConfig {
            CompatibleConfig(
                displayName: "Custom",
                baseURL: "http://localhost:8000/v1",
                modelName: "default",
                hasAPIKey: false
            )
        }

        var keychainId: String {
            return "custom:\(id.uuidString)"
        }

        var configHash: Int {
            var hasher = Hasher()
            hasher.combine(baseURL)
            hasher.combine(modelName)
            hasher.combine(hasAPIKey)
            return hasher.finalize()
        }
    }

    // MARK: - Initialization

    init(config: TranslationEngineConfig, keychain: KeychainService) async throws {
        self.config = config
        self.keychain = keychain
        self.instanceIndex = 0

        // Parse compatible config from customName or create default
        if let customName = config.customName,
           let jsonData = customName.data(using: .utf8),
           let compatibleConfig = try? JSONDecoder().decode(CompatibleConfig.self, from: jsonData) {
            self.compatibleConfig = compatibleConfig
        } else {
            self.compatibleConfig = .default
        }

        self.id = "custom"
        self.name = compatibleConfig.displayName
        self.configHash = compatibleConfig.configHash
    }

    init(
        config: TranslationEngineConfig,
        compatibleConfig: CompatibleConfig,
        instanceIndex: Int,
        keychain: KeychainService
    ) async throws {
        self.config = config
        self.compatibleConfig = compatibleConfig
        self.instanceIndex = instanceIndex
        self.keychain = keychain
        self.id = compatibleConfig.keychainId
        self.name = compatibleConfig.displayName
        self.configHash = compatibleConfig.configHash
    }

    // MARK: - TranslationProvider Protocol

    var isAvailable: Bool {
        get async {
            if compatibleConfig.hasAPIKey {
                let keychainId = compatibleConfig.keychainId
                return await keychain.hasCredentials(forCompatibleId: keychainId)
            }
            return true
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

        let keychainId = compatibleConfig.keychainId
        let credentials = compatibleConfig.hasAPIKey ? try await keychain.getCredentials(forCompatibleId: keychainId) : nil

        let prompt = buildPrompt(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        let start = Date()
        let translatedText = try await callAPI(prompt: prompt, credentials: credentials)
        let latency = Date().timeIntervalSince(start)

        logger.info("Custom translation completed in \(latency)s")

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

        // Combine texts for efficiency
        let combinedText = texts.joined(separator: "\n---\n")
        let combinedResult = try await translate(
            text: combinedText,
            from: sourceLanguage,
            to: targetLanguage
        )

        let translatedTexts = combinedResult.translatedText.components(separatedBy: "\n---\n")

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
            _ = try await translate(text: "Hello", from: "en", to: "zh")
            return true
        } catch {
            logger.error("Connection check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func buildPrompt(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) -> String {
        let source = sourceLanguage ?? "auto-detect"
        return """
            Translate the following text from \(source) to \(targetLanguage).
            Provide ONLY the translated text without any explanations or additional text.

            Text to translate:
            \(text)
            """
    }

    private func callAPI(
        prompt: String,
        credentials: StoredCredentials?
    ) async throws -> String {
        guard let url = URL(string: compatibleConfig.baseURL) else {
            throw TranslationProviderError.invalidConfiguration("Invalid base URL")
        }

        let endpoint = url.appendingPathComponent("chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.options?.timeout ?? 60

        // Add authorization if API key is configured
        if let apiKey = credentials?.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Build OpenAI-compatible request body
        let body: [String: Any] = [
            "model": compatibleConfig.modelName,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": config.options?.temperature ?? 0.3,
            "max_tokens": config.options?.maxTokens ?? 2048
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
}
