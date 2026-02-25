//
//  DeepLTranslationProvider.swift
//  ScreenTranslate
//
//  DeepL Translation API provider
//

import Foundation
import os.log

/// DeepL Translation API provider
actor DeepLTranslationProvider: TranslationProvider {
    // MARK: - Properties

    nonisolated let id: String = "deepl"
    nonisolated let name: String = "DeepL"

    private let config: TranslationEngineConfig
    private let keychain: KeychainService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "DeepLTranslationProvider"
    )

    private var baseURL: String {
        // Use free tier URL if configured, otherwise pro tier
        if let customURL = config.options?.baseURL, !customURL.isEmpty {
            return customURL
        }
        return "https://api.deepl.com/v2/translate"
    }

    // MARK: - Initialization

    init(config: TranslationEngineConfig, keychain: KeychainService) async throws {
        self.config = config
        self.keychain = keychain
    }

    // MARK: - TranslationProvider Protocol

    var isAvailable: Bool {
        get async {
            await keychain.hasCredentials(for: .deepl)
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

        guard let credentials = try await keychain.getCredentials(for: .deepl) else {
            throw TranslationProviderError.invalidConfiguration("API key not configured")
        }

        let start = Date()

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = config.options?.timeout ?? 30

        var body: [String: Any] = [
            "text": [text],
            "target_lang": targetLanguage.uppercased()
        ]

        if let source = sourceLanguage {
            body["source_lang"] = source.uppercased()
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("DeepL API error (\(httpResponse.statusCode)): \(errorMessage)")

            if httpResponse.statusCode == 401 {
                throw TranslationProviderError.invalidConfiguration("Invalid API key")
            } else if httpResponse.statusCode == 429 {
                throw TranslationProviderError.rateLimited(retryAfter: nil)
            } else if httpResponse.statusCode == 456 {
                throw TranslationProviderError.translationFailed("Quota exceeded")
            }

            throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
        }

        let translatedText = try parseResponse(data)
        let latency = Date().timeIntervalSince(start)

        logger.info("DeepL translation completed in \(latency)s")

        return TranslationResult(
            sourceText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage ?? "auto",
            targetLanguage: targetLanguage
        )
    }

    func translate(
        texts: [String],
        from sourceLanguage: String?,
        to targetLanguage: String
    ) async throws -> [TranslationResult] {
        guard !texts.isEmpty else { return [] }

        // DeepL supports batch translation with multiple texts
        guard let credentials = try await keychain.getCredentials(for: .deepl) else {
            throw TranslationProviderError.invalidConfiguration("API key not configured")
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = config.options?.timeout ?? 30

        var body: [String: Any] = [
            "text": texts,
            "target_lang": targetLanguage.uppercased()
        ]

        if let source = sourceLanguage {
            body["source_lang"] = source.uppercased()
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("DeepL API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
        }

        let translations = try parseBatchResponse(data)

        return zip(texts, translations).map { source, translated in
            TranslationResult(
                sourceText: source,
                translatedText: translated,
                sourceLanguage: sourceLanguage ?? "auto",
                targetLanguage: targetLanguage
            )
        }
    }

    func checkConnection() async -> Bool {
        do {
            _ = try await translate(text: "test", from: "en", to: "zh")
            return true
        } catch {
            logger.error("DeepL connection check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let text = firstTranslation["text"] as? String else {
            throw TranslationProviderError.translationFailed("Failed to parse DeepL response")
        }

        return text
    }

    private func parseBatchResponse(_ data: Data) throws -> [String] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]] else {
            throw TranslationProviderError.translationFailed("Failed to parse DeepL response")
        }

        return translations.compactMap { $0["text"] as? String }
    }
}
