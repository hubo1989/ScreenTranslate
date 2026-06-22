import CoreGraphics
import XCTest
@testable import TransFrame

@available(macOS 13.0, *)
final class PipelineSmokeTests: XCTestCase {
    func testAnalysisPipelineFallsBackWhenAnalyzerLeaksPrompt() async throws {
        let recorder = PerformanceRecorder()
        let image = try XCTUnwrap(Self.makeImage())
        let pipeline = AnalysisPipeline(
            analyzer: { _ in
                ScreenAnalysisResult(
                    segments: [
                        TextSegment(text: "置信度: 0.0-1.0", boundingBox: .zero, confidence: 1),
                        TextSegment(text: "x, y: 左上角 (0.0-1.0)", boundingBox: .zero, confidence: 1)
                    ],
                    imageSize: CGSize(width: 16, height: 16)
                )
            },
            ocrFallback: { _ in
                OCRResult(
                    observations: [
                        OCRText(
                            text: "Settings",
                            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.1),
                            confidence: 0.9
                        )
                    ],
                    imageSize: CGSize(width: 16, height: 16)
                )
            },
            recorder: recorder
        )

        let result = try await pipeline.analyze(image: image, context: PipelineContext())

        XCTAssertEqual(result.segments.map(\.text), ["Settings"])
        let summaries = await recorder.summaries()
        XCTAssertEqual(summaries[.analysis]?.count, 1)
    }

    func testTranslationRenderPipelineSupportsTranslationOnlyAndRender() async throws {
        let recorder = PerformanceRecorder()
        let image = try XCTUnwrap(Self.makeImage())
        let segment = TextSegment(text: "Hello", boundingBox: .zero, confidence: 1)
        let service = MockTranslationServicing(
            nextResult: [
                BilingualSegment(
                    original: segment,
                    translated: "你好",
                    sourceLanguage: "English",
                    targetLanguage: "Chinese"
                )
            ]
        )
        let pipeline = TranslationRenderPipeline(
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
        let context = PipelineContext()

        let translated = try await pipeline.translate(
            analysisResult: ScreenAnalysisResult(
                segments: [segment],
                imageSize: CGSize(width: 16, height: 16)
            ),
            config: config,
            context: context
        )
        let rendered = try await pipeline.render(
            image: image,
            segments: translated,
            theme: .light,
            context: context
        )

        XCTAssertEqual(translated.map(\.translated), ["你好"])
        XCTAssertEqual(rendered.width, image.width)
        let summaries = await recorder.summaries()
        XCTAssertEqual(summaries[.translation]?.count, 1)
        XCTAssertEqual(summaries[.render]?.count, 1)
    }

    func testTranslationRenderPipelineThrowsWhenSegmentCountsMismatch() async throws {
        let segment = TextSegment(text: "Hello", boundingBox: .zero, confidence: 1)
        let service = MockTranslationServicing(nextResult: [])
        let pipeline = TranslationRenderPipeline(
            translationService: service,
            renderer: { image, _, _ in image },
            recorder: PerformanceRecorder()
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

        do {
            _ = try await pipeline.translate(
                analysisResult: ScreenAnalysisResult(
                    segments: [segment],
                    imageSize: CGSize(width: 16, height: 16)
                ),
                config: config,
                context: PipelineContext()
            )
            XCTFail("Expected translation count mismatch")
        } catch let error as PipelineError {
            XCTAssertEqual(error.category, .translation)
        }
    }

    func testCapturePipelineRefreshesDisplayLookupOnlyWhenStale() async throws {
        let recorder = PerformanceRecorder()
        let pipeline = CapturePipeline(recorder: recorder)
        let context = PipelineContext()
        let refreshCount = LockedCounter()

        let first: Int = try await pipeline.lookupDisplay(
            context: context,
            freshness: .refreshIfOlderThan(60),
            refresh: {
                await refreshCount.increment()
            },
            lookup: {
                1
            }
        )
        let second: Int = try await pipeline.lookupDisplay(
            context: context,
            freshness: .refreshIfOlderThan(60),
            refresh: {
                await refreshCount.increment()
            },
            lookup: {
                2
            }
        )

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        let refreshes = await refreshCount.currentValue()
        XCTAssertEqual(refreshes, 1)
        let summaries = await recorder.summaries()
        XCTAssertEqual(summaries[.displayLookup]?.count, 2)
    }

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

private actor LockedCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    func currentValue() -> Int {
        value
    }
}
