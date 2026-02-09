//
//  ClaudeVLMProvider.swift
//  ScreenTranslate
//
//  Created for US-006: Claude Vision Provider
//

import CoreGraphics
import Foundation

// MARK: - Claude VLM Provider

/// VLM provider implementation for Anthropic Claude Vision models
struct ClaudeVLMProvider: VLMProvider, Sendable {
    // MARK: - Properties

    let id: String = "claude"
    let name: String = "Claude Vision"
    let configuration: VLMProviderConfiguration

    /// Default Anthropic API base URL
    static let defaultBaseURL = URL(string: "https://api.anthropic.com")!

    /// Default model for vision tasks
    static let defaultModel = "claude-sonnet-4-20250514"

    /// Anthropic API version header
    private static let apiVersion = "2023-06-01"

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
    ///   - apiKey: Anthropic API key
    ///   - baseURL: API base URL (default: Anthropic's official endpoint)
    ///   - modelName: Model to use (default: claude-sonnet-4-20250514)
    ///   - timeout: Request timeout in seconds (default: 60)
    init(
        apiKey: String,
        baseURL: URL = ClaudeVLMProvider.defaultBaseURL,
        modelName: String = ClaudeVLMProvider.defaultModel,
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
        let vlmResponse = try parseClaudeResponse(responseData)

        return vlmResponse.toScreenAnalysisResult(imageSize: imageSize)
    }

    // MARK: - Private Methods

    /// Builds the URLRequest for Anthropic Messages API
    private func buildRequest(base64Image: String) throws -> URLRequest {
        let endpoint = configuration.baseURL.appendingPathComponent("v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeout

        let requestBody = ClaudeMessagesRequest(
            model: configuration.modelName,
            maxTokens: 8192,
            system: VLMPromptTemplate.systemPrompt,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: [
                        .image(ClaudeImageContent(
                            source: ClaudeImageSource(
                                type: "base64",
                                mediaType: "image/jpeg",
                                data: base64Image
                            )
                        )),
                        .text(VLMPromptTemplate.userPrompt),
                    ]
                ),
            ]
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

        if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data),
           let retryAfter = errorResponse.error.retryAfter
        {
            return retryAfter
        }

        return nil
    }

    /// Parses error message from Claude error response
    private func parseErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error.message
    }

    /// Parses Claude response and extracts VLM analysis
    private func parseClaudeResponse(_ data: Data) throws -> VLMAnalysisResponse {
        if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data),
           errorResponse.type == "error" {
            throw VLMProviderError.invalidResponse(errorResponse.error.message)
        }

        let decoder = JSONDecoder()

        let claudeResponse: ClaudeMessagesResponse
        do {
            claudeResponse = try decoder.decode(ClaudeMessagesResponse.self, from: data)
        } catch {
            throw VLMProviderError.parsingFailed("Failed to decode Claude response: \(error.localizedDescription)")
        }

        // Check if response was truncated due to max_tokens
        if claudeResponse.stopReason == "max_tokens" {
            print("[ClaudeVLMProvider] Response truncated due to max_tokens limit")
            throw VLMProviderError.invalidResponse("Response truncated - image may have too much text")
        }
        
        guard let contentBlocks = claudeResponse.content,
              let textBlock = contentBlocks.first(where: { $0.type == "text" }),
              let content = textBlock.text
        else {
            throw VLMProviderError.invalidResponse("No text content in response")
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

// MARK: - Claude API Request/Response Models

/// Claude Messages API request structure
private struct ClaudeMessagesRequest: Encodable, Sendable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

/// Claude message with support for multimodal content
private struct ClaudeMessage: Encodable, Sendable {
    let role: String
    let content: [ClaudeContentBlock]
}

/// Content block that can be text or image
private enum ClaudeContentBlock: Encodable, Sendable {
    case text(String)
    case image(ClaudeImageContent)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(ClaudeTextBlock(type: "text", text: text))
        case .image(let imageContent):
            try container.encode(imageContent)
        }
    }
}

private struct ClaudeTextBlock: Encodable, Sendable {
    let type: String
    let text: String
}

/// Image content structure for Claude vision requests
private struct ClaudeImageContent: Encodable, Sendable {
    let type: String = "image"
    let source: ClaudeImageSource
}

/// Image source with base64 data
private struct ClaudeImageSource: Encodable, Sendable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

/// Claude Messages API response structure
private struct ClaudeMessagesResponse: Decodable, Sendable {
    let id: String?
    let type: String?
    let role: String?
    let content: [ClaudeResponseContentBlock]?
    let model: String?
    let stopReason: String?
    let usage: ClaudeUsage?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

private struct ClaudeResponseContentBlock: Decodable, Sendable {
    let type: String
    let text: String?
}

private struct ClaudeUsage: Decodable, Sendable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// Claude error response structure
private struct ClaudeErrorResponse: Decodable, Sendable {
    let type: String
    let error: ClaudeError
}

private struct ClaudeError: Decodable, Sendable {
    let type: String
    let message: String
    let retryAfter: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case type, message
        case retryAfter = "retry_after"
    }
}
