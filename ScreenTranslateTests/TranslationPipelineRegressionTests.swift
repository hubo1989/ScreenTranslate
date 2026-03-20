import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class TranslationPipelineRegressionTests: XCTestCase {
    func testPromptLeakageHeuristicIdentifiesSchemaInstructions() {
        let leakage = TextSegment(
            text: "- x, y: 左上角 (0.0-1.0) - 宽度, 高度: 箱形尺寸 (0.0-1.0)",
            boundingBox: .zero,
            confidence: 0.99
        )
        let realUI = TextSegment(
            text: "ScreenTranslate",
            boundingBox: .zero,
            confidence: 0.99
        )

        XCTAssertTrue(leakage.isLikelyOCRPromptLeakage)
        XCTAssertFalse(realUI.isLikelyOCRPromptLeakage)
    }

    func testRecoverAnalysisResultFallsBackToOCRWhenVLMOutputIsOnlyPromptLeakage() async throws {
        let leakedAnalysis = ScreenAnalysisResult(
            segments: [
                TextSegment(
                    text: "置信度: 0.0-1.0",
                    boundingBox: .zero,
                    confidence: 0.99
                ),
                TextSegment(
                    text: "- x, y: 左上角 (0.0-1.0)",
                    boundingBox: .zero,
                    confidence: 0.99
                )
            ],
            imageSize: CGSize(width: 1200, height: 800)
        )
        let ocrFallback = OCRResult(
            observations: [
                OCRText(
                    text: "ScreenTranslate",
                    boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05),
                    confidence: 0.95
                ),
                OCRText(
                    text: "Superset",
                    boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.05),
                    confidence: 0.94
                )
            ],
            imageSize: CGSize(width: 1200, height: 800)
        )

        let recovered = try await TranslationFlowController.recoverAnalysisResultIfNeeded(leakedAnalysis) {
            ocrFallback
        }

        XCTAssertEqual(recovered.segments.map(\.text), ["ScreenTranslate", "Superset"])
    }

    @available(macOS 13.0, *)
    func testTranslationEngineSourceLocaleLanguageUsesNilForAutoDetect() {
        XCTAssertNil(TranslationEngine.sourceLocaleLanguage(for: nil))
        XCTAssertNil(TranslationEngine.sourceLocaleLanguage(for: .auto))
        XCTAssertEqual(
            TranslationEngine.sourceLocaleLanguage(for: .japanese)?.minimalIdentifier,
            Locale.Language(identifier: "ja").minimalIdentifier
        )
    }

    func testPromptDisplayNameUsesHumanReadableLanguageNames() {
        XCTAssertEqual(TranslationLanguage.promptDisplayName(for: nil), "Auto Detect")
        XCTAssertEqual(TranslationLanguage.promptDisplayName(for: "auto"), "Auto Detect")
        XCTAssertEqual(TranslationLanguage.promptDisplayName(for: "zh-Hans"), "Chinese (Simplified)")
        XCTAssertEqual(TranslationLanguage.promptDisplayName(for: "ja"), "Japanese")
    }

    func testNoiseHeuristicFiltersCoordinateLikeText() {
        let tick = TextSegment(text: "12.5%", boundingBox: .zero, confidence: 0.95)
        let sentence = TextSegment(text: "Revenue growth", boundingBox: .zero, confidence: 0.95)
        let monthTick = TextSegment(
            text: "Jan",
            boundingBox: CGRect(x: 0.01, y: 0.94, width: 0.05, height: 0.02),
            confidence: 0.99
        )

        XCTAssertTrue(tick.isLikelyTranslationNoise)
        XCTAssertTrue(monthTick.isLikelyTranslationNoise)
        XCTAssertFalse(sentence.isLikelyTranslationNoise)
    }

    func testFilteredForTranslationRemovesNoiseButKeepsContent() {
        let segments = [
            TextSegment(text: "100", boundingBox: .zero, confidence: 0.99),
            TextSegment(text: "Q4 Revenue increased significantly", boundingBox: .zero, confidence: 0.99),
            TextSegment(text: "25%", boundingBox: .zero, confidence: 0.99)
        ]

        let result = ScreenAnalysisResult(segments: segments, imageSize: CGSize(width: 1000, height: 800))
        let filtered = result.filteredForTranslation()

        XCTAssertEqual(filtered.segments.count, 1)
        XCTAssertEqual(filtered.segments.first?.text, "Q4 Revenue increased significantly")
    }

    func testFilteredForTranslationReturnsEmptyWhenEverySegmentLooksLikeNoise() {
        let segments = [
            TextSegment(
                text: "Jan",
                boundingBox: CGRect(x: 0.01, y: 0.94, width: 0.05, height: 0.02),
                confidence: 0.99
            ),
            TextSegment(
                text: "2024",
                boundingBox: CGRect(x: 0.95, y: 0.40, width: 0.03, height: 0.02),
                confidence: 0.99
            )
        ]

        let result = ScreenAnalysisResult(segments: segments, imageSize: CGSize(width: 1200, height: 800))
        let filtered = result.filteredForTranslation()

        XCTAssertTrue(filtered.segments.isEmpty)
    }
}
