//
//  GoogleTranslationProvider.swift
//  ScreenTranslate
//
//  Google Cloud Translation API provider
//

import Foundation
import os.log

/// Google Cloud Translation API provider
actor GoogleTranslationProvider: TranslationProvider {
    // MARK: - Properties

    nonisolated let id: String = "google"
    nonisolated let name: String = "Google Translate"

    private let config: TranslationEngineConfig
    private let keychain: KeychainService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "GoogleTranslationProvider"
    )

    private let baseURL = "https://translation.googleapis.com/language/translate/v2"

    // MARK: - Initialization

    init(config: TranslationEngineConfig, keychain: KeychainService) async throws {
        self.config = config
        self.keychain = keychain
    }

    // MARK: - TranslationProvider Protocol

    var isAvailable: Bool {
        get async {
            await keychain.hasCredentials(for: .google)
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

        guard let credentials = try await keychain.getCredentials(for: .google) else {
            throw TranslationProviderError.invalidConfiguration("API key not configured")
        }

        let start = Date()

        // Google Cloud Translation API v2 uses query parameter for API key
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: credentials.apiKey)]

        guard let url = urlComponents.url else {
            throw TranslationProviderError.invalidConfiguration("Invalid Google Translation API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.options?.timeout ?? 30

        var body: [String: Any] = [
            "q": text,
            "target": targetLanguage,
            "format": "text"
        ]

        if let source = sourceLanguage {
            body["source"] = source
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            // Log status code only to avoid exposing user text in logs
            logger.error("Google API error status=\(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw TranslationProviderError.invalidConfiguration("Invalid API key")
            } else if httpResponse.statusCode == 429 {
                throw TranslationProviderError.rateLimited(retryAfter: nil)
            }

            throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
        }

        let translatedText = try parseResponse(data)
        let latency = Date().timeIntervalSince(start)

        logger.info("Google translation completed in \(latency)s")

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

        // Google supports batch translation with multiple 'q' values
        guard let credentials = try await keychain.getCredentials(for: .google) else {
            throw TranslationProviderError.invalidConfiguration("API key not configured")
        }

        // Google Cloud Translation API v2 uses query parameter for API key
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: credentials.apiKey)]

        guard let url = urlComponents.url else {
            throw TranslationProviderError.invalidConfiguration("Invalid Google Translation API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.options?.timeout ?? 30

        var body: [String: Any] = [
            "q": texts,
            "target": targetLanguage,
            "format": "text"
        ]

        if let source = sourceLanguage {
            body["source"] = source
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            // Log status code only to avoid exposing user text in logs
            logger.error("Google API error status=\(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw TranslationProviderError.invalidConfiguration("Invalid API key")
            } else if httpResponse.statusCode == 429 {
                throw TranslationProviderError.rateLimited(retryAfter: nil)
            }

            throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
        }

        let translations = try parseBatchResponse(data)

        guard translations.count == texts.count else {
            throw TranslationProviderError.translationFailed("Google batch response count mismatch: expected \(texts.count), got \(translations.count)")
        }

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
            logger.error("Google connection check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["data"] as? [String: Any],
              let translations = responseData["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let translatedText = firstTranslation["translatedText"] as? String else {
            throw TranslationProviderError.translationFailed("Failed to parse Google response")
        }

        return translatedText
    }

    private func parseBatchResponse(_ data: Data) throws -> [String] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["data"] as? [String: Any],
              let translations = responseData["translations"] as? [[String: Any]] else {
            throw TranslationProviderError.translationFailed("Failed to parse Google response")
        }

        return translations.compactMap { $0["translatedText"] as? String }
    }
}
