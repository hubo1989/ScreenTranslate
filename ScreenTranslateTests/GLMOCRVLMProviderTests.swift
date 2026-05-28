import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class GLMOCRVLMProviderTests: XCTestCase {
    func testParseResponseMapsLayoutDetailsToScreenSegments() throws {
        let json = """
        {
          "id": "task_123",
          "model": "GLM-OCR",
          "layout_details": [
            [
              {
                "index": 1,
                "label": "text",
                "bbox_2d": [0.1, 0.2, 0.4, 0.3],
                "content": "Hello world",
                "width": 1200,
                "height": 800
              },
              {
                "index": 2,
                "label": "table",
                "bbox_2d": [0.5, 0.2, 0.9, 0.6],
                "content": "<table><tr><td>Total</td><td>42</td></tr></table>",
                "width": 1200,
                "height": 800
              },
              {
                "index": 3,
                "label": "image",
                "bbox_2d": [0.0, 0.0, 0.2, 0.2],
                "content": "https://example.com/image.png",
                "width": 1200,
                "height": 800
              }
            ]
          ],
          "data_info": {
            "num_pages": 1,
            "pages": [
              {
                "width": 1200,
                "height": 800
              }
            ]
          }
        }
        """

        let result = try GLMOCRVLMProvider.parseResponse(
            Data(json.utf8),
            fallbackImageSize: CGSize(width: 100, height: 100)
        )

        XCTAssertEqual(result.imageSize, CGSize(width: 1200, height: 800))
        XCTAssertEqual(result.segments.map(\.text), ["Hello world", "Total 42"])
        XCTAssertEqual(result.segments.count, 2)
        guard result.segments.count == 2 else { return }
        assertRect(result.segments[0].boundingBox, equals: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1))
        assertRect(result.segments[1].boundingBox, equals: CGRect(x: 0.5, y: 0.2, width: 0.4, height: 0.4))
    }

    func testParseLocalResponseMapsOpenAICompatibleContentToScreenSegments() throws {
        let json = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"segments\\":[{\\"text\\":\\"Local OCR\\",\\"boundingBox\\":{\\"x\\":0.2,\\"y\\":0.3,\\"width\\":0.4,\\"height\\":0.1},\\"confidence\\":0.98}]}"
              }
            }
          ]
        }
        """

        let result = try GLMOCRVLMProvider.parseLocalResponse(
            Data(json.utf8),
            fallbackImageSize: CGSize(width: 640, height: 480)
        )

        XCTAssertEqual(result.imageSize, CGSize(width: 640, height: 480))
        XCTAssertEqual(result.segments.map(\.text), ["Local OCR"])
        XCTAssertEqual(result.segments.count, 1)
        guard result.segments.count == 1 else { return }
        assertRect(result.segments[0].boundingBox, equals: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.1))
    }

    func testParseLocalResponseSupportsTextOnlyPayload() throws {
        let json = #"""
        {
          "choices": [
            {
              "message": {
                "content": "{\"Text\":\"返回 200\\n-scheme ScreenTranslate -destination 'platform=macOS'\"}"
              }
            }
          ]
        }
        """#

        let result = try GLMOCRVLMProvider.parseLocalResponse(
            Data(json.utf8),
            fallbackImageSize: CGSize(width: 640, height: 480)
        )

        XCTAssertEqual(
            result.segments.map(\.text),
            ["返回 200", "-scheme ScreenTranslate -destination 'platform=macOS'"]
        )
    }

    private func assertRect(_ actual: CGRect, equals expected: CGRect, accuracy: CGFloat = 0.0001) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy)
        XCTAssertEqual(actual.size.width, expected.size.width, accuracy: accuracy)
        XCTAssertEqual(actual.size.height, expected.size.height, accuracy: accuracy)
    }
}

final class OpenAIVLMProviderTests: XCTestCase {
    var provider: OpenAIVLMProvider!

    override func setUp() {
        super.setUp()
        let config = VLMProviderConfiguration(apiKey: "test-key", baseURL: URL(string: "https://api.openai.com/v1")!, modelName: "gpt-4o")
        provider = OpenAIVLMProvider(configuration: config)
    }

    func testExtractContentAndStatusWithReasoningContentFallback() throws {
        let json = """
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "",
                "reasoning_content": "{\\"segments\\":[]}"
              },
              "finish_reason": "stop"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let (content, isTruncated, finishReason) = try provider.extractContentAndStatus(from: data)
        XCTAssertEqual(content, "{\"segments\":[]}")
        XCTAssertFalse(isTruncated)
        XCTAssertEqual(finishReason, "stop")
    }

    func testExtractContentAndStatusWithReasoningFallback() throws {
        let json = """
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "  ",
                "reasoning": "{\\"segments\\":[]}"
              },
              "finish_reason": "stop"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let (content, isTruncated, finishReason) = try provider.extractContentAndStatus(from: data)
        XCTAssertEqual(content, "{\"segments\":[]}")
        XCTAssertFalse(isTruncated)
        XCTAssertEqual(finishReason, "stop")
    }

    func testExtractContentManuallyWithReasoningFallback() throws {
        // Broken JSON structure but has reasoning_content
        let brokenJSON = """
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": null,
                "reasoning_content": "{\\"segments\\":[]}"
              }
        """
        let extracted = provider.extractContentManually(from: brokenJSON)
        XCTAssertEqual(extracted, "{\"segments\":[]}")
        
        // Broken JSON structure but has reasoning
        let brokenJSON2 = """
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "",
                "reasoning": "{\\"segments\\":[]}"
              }
        """
        let extracted2 = provider.extractContentManually(from: brokenJSON2)
        XCTAssertEqual(extracted2, "{\"segments\":[]}")
    }

    func testParseVLMContentWithEmptyResponseError() {
        XCTAssertThrowsError(try provider.parseVLMContent("   ")) { error in
            guard let providerError = error as? VLMProviderError else {
                XCTFail("Expected VLMProviderError")
                return
            }
            XCTAssertTrue(providerError.localizedDescription.contains("Received empty response from model"))
        }
    }

    func testParseVLMContentWithCleanedEmptyError() {
        // A response that has code blocks but nothing inside
        let content = "```json\n```"
        XCTAssertThrowsError(try provider.parseVLMContent(content)) { error in
            guard let providerError = error as? VLMProviderError else {
                XCTFail("Expected VLMProviderError")
                return
            }
            XCTAssertTrue(providerError.localizedDescription.contains("Cleaned content is empty"))
            XCTAssertTrue(providerError.localizedDescription.contains("```json"))
        }
    }
}
