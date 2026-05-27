import Foundation

/// Service to fetch available model IDs from /models (or Ollama /api/tags) endpoint
enum ModelDiscoveryService {
    
    // MARK: - API Response Structures
    
    private struct OpenAIModel: Codable {
        let id: String
    }
    
    private struct OpenAIModelsResponse: Codable {
        let data: [OpenAIModel]
    }
    
    private struct OllamaModel: Codable {
        let name: String
    }
    
    private struct OllamaTagsResponse: Codable {
        let models: [OllamaModel]
    }
    
    // MARK: - Public Fetch Method
    
    /// Fetch model names/IDs from a specific base URL
    /// - Parameters:
    ///   - baseURL: The api base URL string (e.g., "https://api.openai.com/v1")
    ///   - apiKey: Optional API Key for Authorization
    ///   - engineType: The engine type string, used to specialize requests (e.g. "ollama")
    /// - Returns: A sorted list of available model IDs
    static func fetchModels(
        baseURL: String,
        apiKey: String?,
        engineType: String?
    ) async throws -> [String] {
        var cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.isEmpty {
            throw NSError(
                domain: "ModelDiscovery",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Base URL is empty"]
            )
        }
        
        // Normalize URL protocol
        if !cleanURL.lowercased().hasPrefix("http://") && !cleanURL.lowercased().hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        let isOllama = (engineType?.lowercased() == "ollama" || cleanURL.contains("11434"))
        
        if isOllama {
            // Try Ollama endpoint
            let tagsURLString = cleanURL.hasSuffix("/") ? "\(cleanURL)api/tags" : "\(cleanURL)/api/tags"
            if let tagsURL = URL(string: tagsURLString) {
                var request = URLRequest(url: tagsURL)
                request.httpMethod = "GET"
                request.timeoutInterval = 10.0
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        if let decoded = try? decoder.decode(OllamaTagsResponse.self, from: data) {
                            let models = decoded.models.map { $0.name }.sorted()
                            if !models.isEmpty {
                                return models
                            }
                        }
                    }
                } catch {
                    // Fail silently here and fall back to standard /models check
                }
            }
        }
        
        // Default OpenAI-compatible endpoint
        var modelsURLString = cleanURL
        if modelsURLString.hasSuffix("/models") {
            // Do nothing
        } else if modelsURLString.hasSuffix("/") {
            modelsURLString += "models"
        } else {
            modelsURLString += "/models"
        }
        
        guard let url = URL(string: modelsURLString) else {
            throw NSError(
                domain: "ModelDiscovery",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(modelsURLString)"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        if let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ModelDiscovery",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "No response from server"]
            )
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(decoding: data, as: UTF8.self)
            let hint = errorMsg.isEmpty ? "" : " (\(errorMsg.prefix(100)))"
            throw NSError(
                domain: "ModelDiscovery",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)\(hint)"]
            )
        }
        
        let decoder = JSONDecoder()
        
        // Format 1: Standard OpenAI Response {"data": [{"id": "gpt-4o"}]}
        if let decoded = try? decoder.decode(OpenAIModelsResponse.self, from: data) {
            return decoded.data.map { $0.id }.sorted()
        }
        
        // Format 2: Direct Array of Model Objects [{"id": "gpt-4o"}]
        if let decodedArray = try? decoder.decode([OpenAIModel].self, from: data) {
            return decodedArray.map { $0.id }.sorted()
        }
        
        // Format 3: Direct Array of Strings ["gpt-4o", "gpt-4o-mini"]
        if let decodedStrings = try? decoder.decode([String].self, from: data) {
            return decodedStrings.sorted()
        }
        
        // Format 4: Ollama tags structure returned on /models (sometimes configured on proxy)
        if let decodedOllama = try? decoder.decode(OllamaTagsResponse.self, from: data) {
            return decodedOllama.models.map { $0.name }.sorted()
        }
        
        throw NSError(
            domain: "ModelDiscovery",
            code: 422,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse models response. Unsupported JSON format."]
        )
    }
}
