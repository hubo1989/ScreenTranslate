import XCTest
@testable import ScreenTranslate

// MARK: - ScreenTranslateError Tests

/// Tests for ScreenTranslateError enum
final class ScreenTranslateErrorTests: XCTestCase {

    // MARK: - Capture Errors

    func testPermissionDeniedErrorDescription() {
        let error = ScreenTranslateError.permissionDenied

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.count > 0)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testDisplayNotFoundErrorDescription() {
        let displayID: CGDirectDisplayID = 12345
        let error = ScreenTranslateError.displayNotFound(displayID)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testDisplayDisconnectedErrorDescription() {
        let error = ScreenTranslateError.displayDisconnected(displayName: "External Monitor")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("External Monitor"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testCaptureFailureErrorDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let error = ScreenTranslateError.captureFailure(underlying: underlyingError)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - Export Errors

    func testInvalidSaveLocationErrorDescription() {
        let url = URL(fileURLWithPath: "/nonexistent/path")
        let error = ScreenTranslateError.invalidSaveLocation(url)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testDiskFullErrorDescription() {
        let error = ScreenTranslateError.diskFull

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testExportEncodingFailedErrorDescription() {
        let error = ScreenTranslateError.exportEncodingFailed(format: .png)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - Clipboard Errors

    func testClipboardWriteFailedErrorDescription() {
        let error = ScreenTranslateError.clipboardWriteFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - Hotkey Errors

    func testHotkeyRegistrationFailedErrorDescription() {
        let error = ScreenTranslateError.hotkeyRegistrationFailed(keyCode: 0x14)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testHotkeyConflictErrorDescription() {
        let error = ScreenTranslateError.hotkeyConflict(existingApp: "OtherApp")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - OCR Errors

    func testOCROperationInProgressErrorDescription() {
        let error = ScreenTranslateError.ocrOperationInProgress

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testOCRInvalidImageErrorDescription() {
        let error = ScreenTranslateError.ocrInvalidImage

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testOCRRecognitionFailedErrorDescription() {
        let error = ScreenTranslateError.ocrRecognitionFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testOCRNoTextFoundErrorDescription() {
        let error = ScreenTranslateError.ocrNoTextFound

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - Sendable Conformance

    func testErrorIsSendable() {
        // Verify Sendable conformance by using in a Sendable closure
        let error = ScreenTranslateError.permissionDenied

        let sendableClosure: @Sendable () -> ScreenTranslateError = {
            return error
        }

        // If this compiles and runs, the error is Sendable
        XCTAssertEqual(sendableClosure(), error)
    }

    // MARK: - CaptureFailureError Helper

    func testCaptureErrorHelper() {
        let error = ScreenTranslateError.captureError(message: "Test error message")

        if case .captureFailure(let underlying) = error {
            XCTAssertTrue(underlying is CaptureFailureError)
            XCTAssertEqual((underlying as? CaptureFailureError)?.message, "Test error message")
        } else {
            XCTFail("Expected captureFailure case")
        }
    }
}

// MARK: - CaptureFailureError Tests

/// Tests for CaptureFailureError struct
final class CaptureFailureErrorTests: XCTestCase {

    func testLocalizedDescription() {
        let error = CaptureFailureError(message: "Capture failed")

        XCTAssertEqual(error.localizedDescription, "Capture failed")
    }

    func testSendableConformance() {
        let error = CaptureFailureError(message: "Test")

        // If this compiles, CaptureFailureError conforms to Sendable
        let sendableClosure: @Sendable () -> CaptureFailureError = {
            return error
        }

        XCTAssertEqual(sendableClosure().message, "Test")
    }
}
