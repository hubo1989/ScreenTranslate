import XCTest
@testable import ScreenTranslate

// MARK: - TextTranslationError Tests

/// Tests for TextTranslationError enum
final class TextTranslationErrorTests: XCTestCase {

    // MARK: - Error Descriptions

    func testEmptyInputErrorDescription() {
        let error = TextTranslationError.emptyInput

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.count > 0)
    }

    func testTranslationFailedErrorDescription() {
        let errorMessage = "API connection timeout"
        let error = TextTranslationError.translationFailed(errorMessage)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains(errorMessage))
    }

    func testCancelledErrorDescription() {
        let error = TextTranslationError.cancelled

        XCTAssertNotNil(error.errorDescription)
    }

    func testServiceUnavailableErrorDescription() {
        let error = TextTranslationError.serviceUnavailable

        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Equatable

    func testErrorEquality() {
        let error1 = TextTranslationError.emptyInput
        let error2 = TextTranslationError.emptyInput
        let error3 = TextTranslationError.cancelled

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testTranslationFailedEquality() {
        let error1 = TextTranslationError.translationFailed("same message")
        let error2 = TextTranslationError.translationFailed("same message")
        let error3 = TextTranslationError.translationFailed("different message")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - Sendable Conformance

    func testErrorIsSendable() {
        // This test verifies that TextTranslationError conforms to Sendable
        // by using it in a way that requires Sendable conformance
        let error = TextTranslationError.translationFailed("test")

        // If this compiles, TextTranslationError conforms to Sendable
        let sendableClosure: @Sendable () -> TextTranslationError = {
            return error
        }

        XCTAssertEqual(sendableClosure(), error)
    }
}

// MARK: - TranslationFlowError Tests

/// Tests for TranslationFlowError enum
final class TranslationFlowErrorTests: XCTestCase {

    // MARK: - Error Descriptions

    func testAnalysisFailureDescription() {
        let error = TranslationFlowError.analysisFailure("OCR failed")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("OCR failed"))
    }

    func testTranslationFailureDescription() {
        let error = TranslationFlowError.translationFailure("Network timeout")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network timeout"))
    }

    func testRenderingFailureDescription() {
        let error = TranslationFlowError.renderingFailure("Image processing error")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Image processing error"))
    }

    func testCancelledDescription() {
        let error = TranslationFlowError.cancelled

        XCTAssertNotNil(error.errorDescription)
    }

    func testNoTextFoundDescription() {
        let error = TranslationFlowError.noTextFound

        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Recovery Suggestions

    func testAnalysisFailureRecoverySuggestion() {
        let error = TranslationFlowError.analysisFailure("test")

        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testTranslationFailureRecoverySuggestion() {
        let error = TranslationFlowError.translationFailure("test")

        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testCancelledRecoverySuggestion() {
        let error = TranslationFlowError.cancelled

        // Cancelled errors typically don't have recovery suggestions
        XCTAssertNil(error.recoverySuggestion)
    }

    // MARK: - Equatable

    func testFlowErrorEquality() {
        let error1 = TranslationFlowError.cancelled
        let error2 = TranslationFlowError.cancelled
        let error3 = TranslationFlowError.noTextFound

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}

// MARK: - TranslationFlowPhase Tests

/// Tests for TranslationFlowPhase enum
final class TranslationFlowPhaseTests: XCTestCase {

    // MARK: - Processing State

    func testIdleIsNotProcessing() {
        let phase = TranslationFlowPhase.idle
        XCTAssertFalse(phase.isProcessing)
    }

    func testAnalyzingIsProcessing() {
        let phase = TranslationFlowPhase.analyzing
        XCTAssertTrue(phase.isProcessing)
    }

    func testTranslatingIsProcessing() {
        let phase = TranslationFlowPhase.translating
        XCTAssertTrue(phase.isProcessing)
    }

    func testRenderingIsProcessing() {
        let phase = TranslationFlowPhase.rendering
        XCTAssertTrue(phase.isProcessing)
    }

    func testCompletedIsNotProcessing() {
        let phase = TranslationFlowPhase.completed
        XCTAssertFalse(phase.isProcessing)
    }

    func testFailedIsNotProcessing() {
        let phase = TranslationFlowPhase.failed(.cancelled)
        XCTAssertFalse(phase.isProcessing)
    }

    // MARK: - Progress

    func testIdleProgress() {
        XCTAssertEqual(TranslationFlowPhase.idle.progress, 0.0)
    }

    func testAnalyzingProgress() {
        XCTAssertEqual(TranslationFlowPhase.analyzing.progress, 0.25)
    }

    func testTranslatingProgress() {
        XCTAssertEqual(TranslationFlowPhase.translating.progress, 0.50)
    }

    func testRenderingProgress() {
        XCTAssertEqual(TranslationFlowPhase.rendering.progress, 0.75)
    }

    func testCompletedProgress() {
        XCTAssertEqual(TranslationFlowPhase.completed.progress, 1.0)
    }

    func testFailedProgress() {
        XCTAssertEqual(TranslationFlowPhase.failed(.cancelled).progress, 0.0)
    }

    // MARK: - Localized Description

    func testAllPhasesHaveLocalizedDescriptions() {
        let phases: [TranslationFlowPhase] = [
            .idle, .analyzing, .translating, .rendering, .completed,
            .failed(.cancelled)
        ]

        for phase in phases {
            XCTAssertNotNil(phase.localizedDescription)
            XCTAssertTrue(phase.localizedDescription.count > 0)
        }
    }

    // MARK: - Equatable

    func testPhaseEquality() {
        XCTAssertEqual(TranslationFlowPhase.idle, TranslationFlowPhase.idle)
        XCTAssertEqual(TranslationFlowPhase.analyzing, TranslationFlowPhase.analyzing)
        XCTAssertNotEqual(TranslationFlowPhase.idle, TranslationFlowPhase.analyzing)
    }

    func testFailedPhaseEquality() {
        let error1 = TranslationFlowError.cancelled
        let error2 = TranslationFlowError.noTextFound

        XCTAssertEqual(TranslationFlowPhase.failed(error1), TranslationFlowPhase.failed(error1))
        XCTAssertNotEqual(TranslationFlowPhase.failed(error1), TranslationFlowPhase.failed(error2))
    }
}
