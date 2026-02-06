//
//  OpenAIVLMProvider.swift
//  ScreenTranslate
//
//  Created for US-005: OpenAI Vision Provider
//

import CoreGraphics
import Foundation

// MARK: - OpenAI VLM Provider

/// VLM provider implementation for OpenAI GPT-4V/GPT-4o vision models
struct OpenAIVLMProvider: VLMProvider, Sendable {
    // MARK: - Properties

    let id: String = "openai"
    let name: String = "OpenAI Vision"
    let configuration: VLMProviderConfiguration

    /// Default OpenAI API base URL
    static let defaultBaseURL = URL(string: "https://api.openai.com/v1")!

    /// Default model for vision tasks
    static let defaultModel = "gpt-4o"

    /// Request timeout in seconds
    private let timeout: TimeInterval

    // MARK: - Initialization

    /// Initialize with full configuration
    /// - Parameters:
    ///   - configuration: VLM provider configuration
    ///   - timeout: Request timeout in seconds (default: 60)
    init(configuration: VLMProviderConfiguration, timeout: TimeInterval = 60) {
        self.configuration = configuration
        self.timeout = timeout
    }

    /// Convenience initializer with individual parameters
    /// - Parameters:
    ///   - apiKey: OpenAI API key
    ///   - baseURL: API base URL (default: OpenAI's official endpoint)
    ///   - modelName: Model to use (default: gpt-4o)
    ///   - timeout: Request timeout in seconds (default: 60)
    init(
        apiKey: String,
        baseURL: URL = OpenAIVLMProvider.defaultBaseURL,
        modelName: String = OpenAIVLMProvider.defaultModel,
        timeout: TimeInterval = 60
    ) {
        self.configuration = VLMProviderConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            modelName: modelName
        )
        self.timeout = timeout
    }

    // MARK: - VLMProvider Protocol

    var isAvailable: Bool {
        get async {
            !configuration.apiKey.isEmpty
        }
    }

    func analyze(image: CGImage) async throws -> ScreenAnalysisResult {
        guard let imageData = image.jpegData(quality: 0.85), !imageData.isEmpty else {
            throw VLMProviderError.imageEncodingFailed
        }

        let base64Image = imageData.base64EncodedString()
        let imageSize = CGSize(width: image.width, height: image.height)
        let request = try buildRequest(base64Image: base64Image)
        let responseData = try await executeRequest(request)
        let vlmResponse = try parseOpenAIResponse(responseData)

        return vlmResponse.toScreenAnalysisResult(imageSize: imageSize)
    }

    // MARK: - Private Methods

    /// Builds the URLRequest for OpenAI Chat Completions API
    private func buildRequest(base64Image: String) throws -> URLRequest {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        let requestBody = OpenAIChatRequest(
            model: configuration.modelName,
            messages: [
                OpenAIChatMessage(
                    role: "system",
                    content: .text(VLMPromptTemplate.systemPrompt)
                ),
                OpenAIChatMessage(
                    role: "user",
                    content: .vision([
                        .text(VLMPromptTemplate.userPrompt),
                        .imageURL(OpenAIImageURL(
                            url: "data:image/jpeg;base64,\(base64Image)"
                        )),
                    ])
                ),
            ],
            maxTokens: 4096,
            temperature: 0.1
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        return request
    }

    /// Executes the HTTP request with timeout handling
    private func executeRequest(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw VLMProviderError.networkError("Request timed out")
            case .notConnectedToInternet, .networkConnectionLost:
                throw VLMProviderError.networkError("No internet connection")
            default:
                throw VLMProviderError.networkError(error.localizedDescription)
            }
        } catch {
            throw VLMProviderError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VLMProviderError.invalidResponse("Invalid HTTP response")
        }

        try handleHTTPStatus(httpResponse, data: data)

        return data
    }

    /// Handles HTTP status codes and throws appropriate errors
    private func handleHTTPStatus(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200 ... 299:
            return

        case 401:
            throw VLMProviderError.authenticationFailed

        case 429:
            let retryAfter = parseRetryAfter(from: response, data: data)
            throw VLMProviderError.rateLimited(retryAfter: retryAfter)

        case 404:
            throw VLMProviderError.modelUnavailable(configuration.modelName)

        case 400:
            let message = parseErrorMessage(from: data) ?? "Bad request"
            throw VLMProviderError.invalidConfiguration(message)

        case 500 ... 599:
            let message = parseErrorMessage(from: data) ?? "Server error"
            throw VLMProviderError.networkError("Server error (\(response.statusCode)): \(message)")

        default:
            let message = parseErrorMessage(from: data) ?? "Unknown error"
            throw VLMProviderError.invalidResponse("HTTP \(response.statusCode): \(message)")
        }
    }

    /// Parses the retry-after value from rate limit response
    private func parseRetryAfter(from response: HTTPURLResponse, data: Data) -> TimeInterval? {
        if let headerValue = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(headerValue)
        {
            return seconds
        }

        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data),
           let retryAfter = errorResponse.error.retryAfter
        {
            return retryAfter
        }

        return nil
    }

    /// Parses error message from OpenAI error response
    private func parseErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error.message
    }

    /// Parses OpenAI response and extracts VLM analysis
    private func parseOpenAIResponse(_ data: Data) throws -> VLMAnalysisResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let openAIResponse: OpenAIChatResponse
        do {
            openAIResponse = try decoder.decode(OpenAIChatResponse.self, from: data)
        } catch {
            throw VLMProviderError.parsingFailed("Failed to decode OpenAI response: \(error.localizedDescription)")
        }

        guard let choice = openAIResponse.choices.first,
              let content = choice.message.content
        else {
            throw VLMProviderError.invalidResponse("No content in response")
        }

        return try parseVLMContent(content)
    }

    /// Parses the VLM JSON content from assistant message
    private func parseVLMContent(_ content: String) throws -> VLMAnalysisResponse {
        let cleanedContent = extractJSON(from: content)

        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw VLMProviderError.parsingFailed("Failed to convert content to data")
        }

        do {
            let response = try JSONDecoder().decode(VLMAnalysisResponse.self, from: jsonData)
            return response
        } catch {
            throw VLMProviderError.parsingFailed(
                "Failed to parse VLM response JSON: \(error.localizedDescription). Content: \(cleanedContent.prefix(200))..."
            )
        }
    }

    /// Extracts JSON from potentially markdown-wrapped content
    private func extractJSON(from content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```json") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }

        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - OpenAI API Request/Response Models

/// OpenAI Chat Completion request structure
private struct OpenAIChatRequest: Encodable, Sendable {
    let model: String
    let messages: [OpenAIChatMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

/// Chat message with support for vision content
private struct OpenAIChatMessage: Encodable, Sendable {
    let role: String
    let content: MessageContent

    enum MessageContent: Sendable {
        case text(String)
        case vision([VisionContent])
    }

    enum VisionContent: Sendable {
        case text(String)
        case imageURL(OpenAIImageURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)

        switch content {
        case .text(let text):
            try container.encode(text, forKey: .content)
        case .vision(let contents):
            var contentArray = container.nestedUnkeyedContainer(forKey: .content)
            for item in contents {
                switch item {
                case .text(let text):
                    try contentArray.encode(["type": "text", "text": text])
                case .imageURL(let imageURL):
                    var itemContainer = contentArray.nestedContainer(keyedBy: VisionCodingKeys.self)
                    try itemContainer.encode("image_url", forKey: .type)
                    try itemContainer.encode(imageURL, forKey: .imageUrl)
                }
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    enum VisionCodingKeys: String, CodingKey {
        case type
        case imageUrl = "image_url"
    }
}

/// Image URL structure for vision requests
private struct OpenAIImageURL: Encodable, Sendable {
    let url: String
    let detail: String

    init(url: String, detail: String = "high") {
        self.url = url
        self.detail = detail
    }
}

/// OpenAI Chat Completion response structure
private struct OpenAIChatResponse: Decodable, Sendable {
    let id: String
    let choices: [OpenAIChatChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIChatChoice: Decodable, Sendable {
    let index: Int
    let message: OpenAIResponseMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

private struct OpenAIResponseMessage: Decodable, Sendable {
    let role: String
    let content: String?
}

private struct OpenAIUsage: Decodable, Sendable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// OpenAI error response structure
private struct OpenAIErrorResponse: Decodable, Sendable {
    let error: OpenAIError
}

private struct OpenAIError: Decodable, Sendable {
    let message: String
    let type: String?
    let code: String?
    let retryAfter: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case message, type, code
        case retryAfter = "retry_after"
    }
}
