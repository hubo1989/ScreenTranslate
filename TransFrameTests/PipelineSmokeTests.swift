import CoreGraphics
import XCTest
@testable import TransFrame

@available(macOS 13.0, *)
final class PipelineSmokeTests: XCTestCase {
    func testImagePipelineStaysWithinMockPerformanceBudget() async throws {
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
                    imageSize: CGSize(width: 16, height: 16)
                )
            },
            ocrFallback: { _ in
                OCRResult(observations: [], imageSize: CGSize(width: 16, height: 16))
            },
            translationService: service,
            renderer: { image, _, _ in image },
            recorder: recorder
        )
        let config = ImageTranslationPipelineConfig(
            targetLanguage: "zh-Hans",
            sourceLanguage: "en",
            preferredEngine: .apple,
            scene: nil,
            mode: .primaryWithFallback,
            fallbackEnabled: true,
            parallelEngines: [],
            sceneBindings: [:]
        )

        for _ in 0..<5 {
            _ = try await pipeline.run(image: image, config: config, theme: .light)
        }

        let summaries = await recorder.summaries()
        XCTAssertTrue(PerformanceBudget(stage: .analysis, p95Milliseconds: 100).allows(try XCTUnwrap(summaries[.analysis])))
        XCTAssertTrue(PerformanceBudget(stage: .translation, p95Milliseconds: 100).allows(try XCTUnwrap(summaries[.translation])))
        XCTAssertTrue(PerformanceBudget(stage: .render, p95Milliseconds: 100).allows(try XCTUnwrap(summaries[.render])))
    }

    private static func makeImage() -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: 16,
            height: 16,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        return context.makeImage()
    }
}

