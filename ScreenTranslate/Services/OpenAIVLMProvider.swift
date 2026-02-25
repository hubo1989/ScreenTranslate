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

    /// Maximum number of continuation attempts when response is truncated
    private let maxContinuationAttempts = 3

    func analyze(image: CGImage) async throws -> ScreenAnalysisResult {
        guard let imageData = image.jpegData(quality: 0.85), !imageData.isEmpty else {
            throw VLMProviderError.imageEncodingFailed
        }

        let base64Image = imageData.base64EncodedString()
        let imageSize = CGSize(width: image.width, height: image.height)
        
        // DEBUG: Log image details
        print("[OpenAI] Image size: \(image.width)x\(image.height), JPEG data: \(imageData.count) bytes, Base64 length: \(base64Image.count) chars")

        // Use multi-turn conversation with continuation support
        let vlmResponse = try await analyzeWithContinuation(
            base64Image: base64Image,
            imageSize: imageSize,
            maxAttempts: maxContinuationAttempts
        )

        return vlmResponse.toScreenAnalysisResult(imageSize: imageSize)
    }

    /// Performs analysis with automatic continuation on truncation
    private func analyzeWithContinuation(
        base64Image: String,
        imageSize: CGSize,
        maxAttempts: Int
    ) async throws -> VLMAnalysisResponse {
        var allSegments: [VLMTextSegment] = []
        var conversationMessages: [OpenAIChatMessage] = [
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
        ]

        for attempt in 0..<maxAttempts {
            let isContinuation = attempt > 0
            let request = try buildRequest(messages: conversationMessages, isContinuation: isContinuation)
            let responseData = try await executeRequest(request)

            let (content, isTruncated, finishReason) = try extractContentAndStatus(from: responseData)

            print("[OpenAI] Attempt \(attempt + 1)/\(maxAttempts): received \(content.count) chars, finish_reason=\(finishReason ?? "unknown")")

            // Try to parse this response
            do {
                let response = try parseVLMContent(content)
                allSegments.append(contentsOf: response.segments)
                print("[OpenAI] Parsed \(response.segments.count) segments from this response")

                if !isTruncated {
                    // Complete - return merged result
                    print("[OpenAI] Complete response received, total \(allSegments.count) segments")
                    return VLMAnalysisResponse(segments: allSegments)
                }
            } catch {
                print("[OpenAI] Parse error on attempt \(attempt + 1): \(error)")

                // Try partial parsing for truncated response
                if isTruncated {
                    if let partial = try? parsePartialVLMContent(content) {
                        allSegments.append(contentsOf: partial.segments)
                        print("[OpenAI] Partial parse recovered \(partial.segments.count) segments")
                    }
                }

                // If not truncated but parse failed, this is a real error
                if !isTruncated {
                    throw error
                }
            }

            // Response truncated, need to continue
            print("[OpenAI] Response truncated, requesting continuation...")

            // Add assistant's partial response to conversation
            conversationMessages.append(OpenAIChatMessage(
                role: "assistant",
                content: .text(content)
            ))

            // Request continuation - ask for complete output this time
            conversationMessages.append(OpenAIChatMessage(
                role: "user",
                content: .text("Continue from where you left off. Return ONLY the complete JSON array of remaining segments. Do not repeat segments already returned.")
            ))
        }

        print("[OpenAI] Max continuation attempts reached, returning \(allSegments.count) accumulated segments")
        return VLMAnalysisResponse(segments: allSegments)
    }

    /// Extracts content text and truncation status from OpenAI response
    private func extractContentAndStatus(from data: Data) throws -> (content: String, isTruncated: Bool, finishReason: String?) {
        // Log raw response first for debugging
        if let rawJSON = String(data: data, encoding: .utf8) {
            print("[OpenAI] Raw response (\(data.count) bytes): \(rawJSON.prefix(500))...")
        }

        // Check for error response first
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data),
           !errorResponse.error.message.isEmpty {
            throw VLMProviderError.invalidResponse(errorResponse.error.message)
        }

        // Try to parse as OpenAI response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let openAIResponse: OpenAIChatResponse
        do {
            openAIResponse = try decoder.decode(OpenAIChatResponse.self, from: data)
        } catch {
            // If JSON decoding fails, try to extract content manually using regex
            // This handles cases where the JSON structure is broken
            if let rawJSON = String(data: data, encoding: .utf8),
               let content = extractContentManually(from: rawJSON) {
                let isTruncated = rawJSON.contains("\"finish_reason\":\"length\"") ||
                                 rawJSON.contains("\"finish_reason\": \"length\"")
                print("[OpenAI] Manually extracted content (truncated: \(isTruncated))")
                return (content, isTruncated, isTruncated ? "length" : nil)
            }

            let rawJSON = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            throw VLMProviderError.parsingFailed("Failed to decode OpenAI response: \(error.localizedDescription). Raw: \(rawJSON.prefix(300))")
        }

        guard let choices = openAIResponse.choices, !choices.isEmpty else {
            throw VLMProviderError.invalidResponse("No choices in response")
        }

        let choice = choices[0]

        guard let message = choice.message else {
            throw VLMProviderError.invalidResponse("No message in choice")
        }

        guard let content = message.content else {
            let reason = choice.finishReason ?? "unknown"
            throw VLMProviderError.invalidResponse("No content in response (finish_reason: \(reason))")
        }

        let isTruncated = choice.finishReason == "length"
        return (content, isTruncated, choice.finishReason)
    }

    /// Attempts to extract content field manually when JSON decoder fails
    private func extractContentManually(from json: String) -> String? {
        print("[OpenAI] extractContentManually: searching in \(json.count) chars")

        let patterns = ["\"content\":\"", "\"content\": \""]

        for pattern in patterns {
            if let range = json.range(of: pattern) {
                let start = range.upperBound
                print("[OpenAI] Found pattern '\(pattern)' at position, start char: '\(json[start])'")

                var end = start
                var escaped = false
                var depth = 0
                var charCount = 0

                for char in json[start...] {
                    charCount += 1
                    if charCount <= 20 {
                        print("[OpenAI] char[\(charCount)]: '\(char)' escaped=\(escaped) depth=\(depth)")
                    }

                    if escaped {
                        escaped = false
                        end = json.index(after: end)
                    } else if char == "\\" {
                        escaped = true
                        end = json.index(after: end)
                    } else if char == "{" || char == "[" {
                        depth += 1
                        end = json.index(after: end)
                    } else if char == "}" || char == "]" {
                        depth -= 1
                        end = json.index(after: end)
                        if depth < 0 {
                            print("[OpenAI] depth went negative at char '\(char)', breaking")
                            break
                        }
                    } else if char == "\"" && depth == 0 {
                        print("[OpenAI] found end quote at depth 0, breaking")
                        break
                    } else {
                        end = json.index(after: end)
                    }
                }

                let content = String(json[start..<end])
                print("[OpenAI] extractContentManually: found content of \(content.count) chars, first 100: \(content.prefix(100))")

                return content
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
                    .replacingOccurrences(of: "\\n", with: "\n")
            }
        }

        print("[OpenAI] extractContentManually: no content pattern found")
        return nil
    }

    // MARK: - Private Methods

    /// Builds the URLRequest for OpenAI Chat Completions API with custom messages
    private func buildRequest(messages: [OpenAIChatMessage], isContinuation: Bool = false) throws -> URLRequest {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        // Use higher max_tokens for continuation requests
        let maxTokens = isContinuation ? 16384 : 8192

        let requestBody = OpenAIChatRequest(
            model: configuration.modelName,
            messages: messages,
            maxTokens: maxTokens,
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

        print("[OpenAI] Sending request to: \(request.url?.absoluteString ?? "unknown")")
        print("[OpenAI] API Key (first 8 chars): \(String(configuration.apiKey.prefix(8)))...")
        if let body = request.httpBody {
            print("[OpenAI] Request body size: \(body.count) bytes")
            // Print first 500 chars of request body for debugging
            if let bodyStr = String(data: body, encoding: .utf8) {
                print("[OpenAI] Request body preview: \(bodyStr.prefix(500))")
            }
        }

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            print("[OpenAI] Network error: \(error)")
            switch error.code {
            case .timedOut:
                throw VLMProviderError.networkError("Request timed out")
            case .notConnectedToInternet, .networkConnectionLost:
                throw VLMProviderError.networkError("No internet connection")
            default:
                throw VLMProviderError.networkError(error.localizedDescription)
            }
        } catch {
            print("[OpenAI] Unknown error: \(error)")
            throw VLMProviderError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VLMProviderError.invalidResponse("Invalid HTTP response")
        }

        print("[OpenAI] HTTP status: \(httpResponse.statusCode), Data size: \(data.count) bytes")

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
            print("[OpenAI] 429 Rate Limited - Response body: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            print("[OpenAI] 429 Response headers: \(response.allHeaderFields)")
            let retryAfter = parseRetryAfter(from: response, data: data)
            let errorMessage = parseErrorMessage(from: data)
            throw VLMProviderError.rateLimited(retryAfter: retryAfter, message: errorMessage)

        case 404:
            throw VLMProviderError.modelUnavailable(configuration.modelName)

        case 400:
            let message = parseErrorMessage(from: data) ?? "Bad request"
            print("[OpenAI] 400 Error - Response body: \(String(data: data, encoding: .utf8) ?? "nil")")
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

    /// Parses the VLM JSON content from assistant message
    private func parseVLMContent(_ content: String, wasTruncated: Bool = false) throws -> VLMAnalysisResponse {
        var cleanedContent = extractJSON(from: content)

        // If response was truncated, try to repair the JSON by closing open brackets
        if wasTruncated {
            print("[OpenAI] Attempting to repair truncated JSON...")
            cleanedContent = attemptToRepairJSON(cleanedContent)
        }

        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw VLMProviderError.parsingFailed("Failed to convert content to data")
        }

        do {
            let response = try JSONDecoder().decode(VLMAnalysisResponse.self, from: jsonData)
            return response
        } catch {
            if wasTruncated {
                throw VLMProviderError.invalidResponse("Response was truncated due to token limit. Try selecting a smaller area or using a model with larger context window.")
            }
            throw VLMProviderError.parsingFailed(
                "Failed to parse VLM response JSON: \(error.localizedDescription). Content: \(cleanedContent.prefix(200))..."
            )
        }
    }

    /// Attempts to parse partial/truncated VLM content by extracting valid JSON segments
    private func parsePartialVLMContent(_ content: String) throws -> VLMAnalysisResponse {
        let cleanedContent = extractJSON(from: content)

        // Try to find the last complete segment object
        // Look for the last complete "}" that closes a segment
        if let lastCompleteBlockEnd = cleanedContent.range(of: "}", options: .backwards) {
            let truncatedContent = String(cleanedContent[..<lastCompleteBlockEnd.upperBound])

            // Try to complete the JSON structure
            var completedJSON = truncatedContent
            if !truncatedContent.hasSuffix("]") {
                completedJSON += "]"
            }
            if !completedJSON.hasSuffix("}") {
                completedJSON += "}"
            }

            guard let jsonData = completedJSON.data(using: .utf8) else {
                throw VLMProviderError.parsingFailed("Failed to convert partial content to data")
            }

            do {
                let response = try JSONDecoder().decode(VLMAnalysisResponse.self, from: jsonData)
                print("[OpenAI] Successfully parsed partial response with \(response.segments.count) segments")
                return response
            } catch {
                // If that didn't work, return empty result with warning
                print("[OpenAI] Partial parse failed, returning empty result")
                return VLMAnalysisResponse(segments: [])
            }
        }

        // Last resort: return empty result
        return VLMAnalysisResponse(segments: [])
    }

    /// Attempts to repair truncated JSON by closing open structures
    private func attemptToRepairJSON(_ json: String) -> String {
        var repaired = json

        // Count unclosed brackets
        let openBraces = repaired.filter { $0 == "{" }.count - repaired.filter { $0 == "}" }.count
        let openBrackets = repaired.filter { $0 == "[" }.count - repaired.filter { $0 == "]" }.count

        // Close any open strings (if odd number of unescaped quotes)
        let quoteCount = repaired.filter { $0 == "\"" }.count
        if quoteCount % 2 != 0 {
            repaired += "\""
        }

        // Close objects and arrays
        for _ in 0..<openBraces {
            repaired += "}"
        }
        for _ in 0..<openBrackets {
            repaired += "]"
        }

        return repaired
    }

    /// Extracts JSON from potentially markdown-wrapped content
    private func extractJSON(from content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle markdown code blocks
        if text.hasPrefix("```json") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }

        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        // Handle case where response starts with text before JSON
        if let jsonStart = text.firstIndex(of: "{"), jsonStart != text.startIndex {
            text = String(text[jsonStart...])
        }

        // Handle case where there's text after the JSON
        if let jsonEnd = text.lastIndex(of: "}") {
            let nextIndex = text.index(after: jsonEnd)
            if nextIndex < text.endIndex {
                text = String(text[...jsonEnd])
            }
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
    let id: String?
    let choices: [OpenAIChatChoice]?
    let usage: OpenAIUsage?
}

private struct OpenAIChatChoice: Decodable, Sendable {
    let index: Int?
    let message: OpenAIResponseMessage?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

private struct OpenAIResponseMessage: Decodable, Sendable {
    let role: String?
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
