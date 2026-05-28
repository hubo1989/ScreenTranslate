import XCTest
@testable import TransFrame

final class ModelDiscoveryServiceTests: XCTestCase {
    
    // MARK: - JSON Parsing Tests
    
    func testParseOpenAIModelsResponse() {
        let jsonString = """
        {
          "object": "list",
          "data": [
            {
              "id": "gpt-4o",
              "object": "model",
              "created": 1686935002,
              "owned_by": "organization"
            },
            {
              "id": "gpt-4o-mini",
              "object": "model",
              "created": 1686935003,
              "owned_by": "organization"
            }
          ]
        }
        """
        
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to convert JSON string to data")
            return
        }
        
        struct OpenAIModel: Codable {
            let id: String
        }
        
        struct OpenAIModelsResponse: Codable {
            let data: [OpenAIModel]
        }
        
        do {
            let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            let models = decoded.data.map { $0.id }.sorted()
            XCTAssertEqual(models.count, 2)
            XCTAssertEqual(models[0], "gpt-4o")
            XCTAssertEqual(models[1], "gpt-4o-mini")
        } catch {
            XCTFail("Decoding failed: \(error.localizedDescription)")
        }
    }
    
    func testParseOllamaTagsResponse() {
        let jsonString = """
        {
          "models": [
            {
              "name": "llama3:latest",
              "modified_at": "2024-06-19T12:00:00Z",
              "size": 4700000000,
              "digest": "sha256:12345"
            },
            {
              "name": "qwen2:7b",
              "modified_at": "2024-06-19T12:00:00Z",
              "size": 4700000000,
              "digest": "sha256:67890"
            }
          ]
        }
        """
        
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to convert JSON string to data")
            return
        }
        
        struct OllamaModel: Codable {
            let name: String
        }
        
        struct OllamaTagsResponse: Codable {
            let models: [OllamaModel]
        }
        
        do {
            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            let models = decoded.models.map { $0.name }.sorted()
            XCTAssertEqual(models.count, 2)
            XCTAssertEqual(models[0], "llama3:latest")
            XCTAssertEqual(models[1], "qwen2:7b")
        } catch {
            XCTFail("Decoding failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation of URL Normalization
    
    func testEmptyURLThrowsError() async {
        do {
            _ = try await ModelDiscoveryService.fetchModels(baseURL: "", apiKey: nil, engineType: nil)
            XCTFail("Expected fetchModels to throw error on empty URL")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("empty"))
        }
    }
}
