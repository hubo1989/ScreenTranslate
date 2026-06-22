import CoreGraphics
import XCTest
@testable import TransFrame

@available(macOS 13.0, *)
final class ImageTranslationPipelineTests: XCTestCase {
    func testPipelineRecordsAnalysisTranslationAndRenderStages() async throws {
        let recorder = PerformanceRecorder()
        let image = try XCTUnwrap(Self.makeImage())
        let service = MockTranslationServicing(
            nextResult: [
                BilingualSegment(
                    original: TextSegment(text: "Hello", boundingBox: .zero, confidence: 1),
                    translated: "你好",
                    sourceLanguage: "English",
                    targetLanguage: "Chinese"
                )
            ]
        )
        let pipeline = ImageTranslationPipeline(
            analyzer: { _ in
                ScreenAnalysisResult(
                    segments: [TextSegment(text: "Hello", boundingBox: .zero, confidence: 1)],
                    imageSize: CGSize(width: 8, height: 8)
                )
            },
            ocrFallback: { _ in
                OCRResult(observations: [], imageSize: CGSize(width: 8, height: 8))
            },
            translationService: service,
            renderer: { image, _, _ in image },
            recorder: recorder
        )

        let output = try await pipeline.run(
            image: image,
            config: ImageTranslationPipelineConfig(
                targetLanguage: "zh-Hans",
                sourceLanguage: "en",
                preferredEngine: .apple,
                scene: nil,
                mode: .primaryWithFallback,
                fallbackEnabled: true,
                parallelEngines: [],
                sceneBindings: [:]
            ),
            theme: .light
        )

        XCTAssertEqual(output.segments.map(\.translated), ["你好"])
        let summaries = await recorder.summaries()
        XCTAssertEqual(summaries[.analysis]?.count, 1)
        XCTAssertEqual(summaries[.translation]?.count, 1)
        XCTAssertEqual(summaries[.render]?.count, 1)
    }

    func testPipelineFallsBackToOCRForPromptLeakage() async throws {
        let image = try XCTUnwrap(Self.makeImage())
        let service = MockTranslationServicing(
            nextResult: [
                BilingualSegment(
                    original: TextSegment(text: "TransFrame", boundingBox: .zero, confidence: 1),
                    translated: "传帧",
                    sourceLanguage: "English",
                    targetLanguage: "Chinese"
                )
            ]
        )
        let pipeline = ImageTranslationPipeline(
            analyzer: { _ in
                ScreenAnalysisResult(
                    segments: [
                        TextSegment(text: "置信度: 0.0-1.0", boundingBox: .zero, confidence: 1),
                        TextSegment(text: "- x, y: 左上角 (0.0-1.0)", boundingBox: .zero, confidence: 1)
                    ],
                    imageSize: CGSize(width: 8, height: 8)
                )
            },
            ocrFallback: { _ in
                OCRResult(
                    observations: [
                        OCRText(
                            text: "TransFrame",
                            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.2),
                            confidence: 0.95
                        )
                    ],
                    imageSize: CGSize(width: 8, height: 8)
                )
            },
            translationService: service,
            renderer: { image, _, _ in image }
        )

        let output = try await pipeline.run(
            image: image,
            config: ImageTranslationPipelineConfig(
                targetLanguage: "zh-Hans",
                sourceLanguage: "en",
                preferredEngine: .apple,
                scene: nil,
                mode: .primaryWithFallback,
                fallbackEnabled: true,
                parallelEngines: [],
                sceneBindings: [:]
            ),
            theme: .light
        )

        XCTAssertEqual(output.filteredAnalysisResult.segments.map(\.text), ["TransFrame"])
    }

    private static func makeImage() -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(CGColor(gray: 1, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return context?.makeImage()
    }
}

