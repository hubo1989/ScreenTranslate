//
//  VLMProvider.swift
//  ScreenTranslate
//
//  Created for US-004: VLM Provider Protocol
//

import Foundation
import CoreGraphics

// MARK: - VLM Provider Configuration

/// Configuration for VLM provider connections
struct VLMProviderConfiguration: Sendable, Equatable {
    let apiKey: String
    let baseURL: URL
    let modelName: String
    
    init(apiKey: String, baseURL: URL, modelName: String) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.modelName = modelName
    }
    
    init(apiKey: String, baseURLString: String, modelName: String) throws {
        guard let url = URL(string: baseURLString) else {
            throw VLMProviderError.invalidConfiguration("Invalid base URL: \(baseURLString)")
        }
        self.apiKey = apiKey
        self.baseURL = url
        self.modelName = modelName
    }
}

// MARK: - VLM Provider Protocol

/// Protocol defining a Vision Language Model provider for screen analysis
/// Implementations can wrap different VLM APIs (OpenAI GPT-4V, Claude Vision, Gemini, etc.)
protocol VLMProvider: Sendable {
    /// Unique identifier for this provider
    var id: String { get }
    
    /// Human-readable name for display
    var name: String { get }
    
    /// Whether the provider is currently available (configured and reachable)
    var isAvailable: Bool { get async }
    
    /// Current configuration
    var configuration: VLMProviderConfiguration { get }
    
    /// Analyze an image and extract text segments with bounding boxes
    /// - Parameter image: The image to analyze
    /// - Returns: Analysis result containing text segments with positions
    /// - Throws: VLMProviderError if analysis fails
    func analyze(image: CGImage) async throws -> ScreenAnalysisResult
}

// MARK: - VLM Provider Errors

/// Errors that can occur during VLM provider operations
enum VLMProviderError: LocalizedError, Sendable {
    case invalidConfiguration(String)
    case networkError(String)
    case authenticationFailed
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse(String)
    case modelUnavailable(String)
    case imageEncodingFailed
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed:
            return "Authentication failed. Please check your API key."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .invalidResponse(let message):
            return "Invalid response from server: \(message)"
        case .modelUnavailable(let model):
            return "Model '\(model)' is not available."
        case .imageEncodingFailed:
            return "Failed to encode image for upload."
        case .parsingFailed(let message):
            return "Failed to parse VLM response: \(message)"
        }
    }
}

// MARK: - VLM Prompt Template

/// Standard prompt template for VLM screen analysis
/// Designed to extract text with bounding boxes in a structured JSON format
enum VLMPromptTemplate {
    
    /// System prompt establishing the VLM's role
    static let systemPrompt = """
        You are a precise screen text extraction assistant. Your task is to identify all visible text \
        in the provided screenshot and return their positions as normalized bounding boxes.
        
        Rules:
        1. Extract ALL visible text, including UI labels, buttons, menus, and content
        2. Return bounding boxes as normalized coordinates (0.0 to 1.0) relative to image dimensions
        3. Group text logically (e.g., a button label is one segment, not individual characters)
        4. Provide confidence scores based on text clarity and readability
        5. Respond ONLY with valid JSON, no additional text
        """
    
    /// User prompt requesting text extraction
    static let userPrompt = """
        Analyze this screenshot and extract all visible text with their positions.
        
        Return a JSON object with this exact structure:
        {
          "segments": [
            {
              "text": "extracted text content",
              "boundingBox": {
                "x": 0.0,
                "y": 0.0,
                "width": 0.0,
                "height": 0.0
              },
              "confidence": 0.95
            }
          ]
        }
        
        Where:
        - x, y: top-left corner position (0.0-1.0, normalized to image size)
        - width, height: dimensions (0.0-1.0, normalized to image size)
        - confidence: 0.0-1.0, how confident you are in the text extraction
        
        Extract all text segments visible in the image.
        """
    
    /// JSON schema description for documentation and API configuration
    /// Used to configure VLM APIs that support structured output (e.g., OpenAI's response_format)
    static let responseSchemaDescription = """
        {
          "type": "object",
          "properties": {
            "segments": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "text": {"type": "string"},
                  "boundingBox": {
                    "type": "object",
                    "properties": {
                      "x": {"type": "number", "minimum": 0, "maximum": 1},
                      "y": {"type": "number", "minimum": 0, "maximum": 1},
                      "width": {"type": "number", "minimum": 0, "maximum": 1},
                      "height": {"type": "number", "minimum": 0, "maximum": 1}
                    },
                    "required": ["x", "y", "width", "height"]
                  },
                  "confidence": {"type": "number", "minimum": 0, "maximum": 1}
                },
                "required": ["text", "boundingBox", "confidence"]
              }
            }
          },
          "required": ["segments"]
        }
        """
}

// MARK: - VLM Response Parsing

/// Response structure from VLM for parsing
struct VLMAnalysisResponse: Codable, Sendable {
    let segments: [VLMTextSegment]
}

struct VLMTextSegment: Codable, Sendable {
    let text: String
    let boundingBox: VLMBoundingBox
    let confidence: Float
}

struct VLMBoundingBox: Codable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Response Conversion Extension

extension VLMAnalysisResponse {
    /// Convert VLM response to ScreenAnalysisResult
    func toScreenAnalysisResult(imageSize: CGSize) -> ScreenAnalysisResult {
        let textSegments = segments.map { segment in
            TextSegment(
                text: segment.text,
                boundingBox: segment.boundingBox.cgRect,
                confidence: segment.confidence
            )
        }
        return ScreenAnalysisResult(segments: textSegments, imageSize: imageSize)
    }
}
