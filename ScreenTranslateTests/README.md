# ScreenTranslate Unit Tests

This directory contains unit tests for the ScreenTranslate application.

## Test Files

| File | Description |
|------|-------------|
| `KeyboardShortcutTests.swift` | Tests for keyboard shortcut model |
| `ScreenTranslateErrorTests.swift` | Tests for error types |
| `TextTranslationErrorTests.swift` | Tests for translation errors and phases |
| `ShortcutRecordingTypeTests.swift` | Tests for shortcut recording enum |

## Adding Tests to Xcode Project

The project does not currently have a test target. To add one:

1. Open `ScreenTranslate.xcodeproj` in Xcode
2. File → New → Target
3. Select **macOS** → **Unit Testing Bundle**
4. Name it `ScreenTranslateTests`
5. Add the test files from this directory to the new target

## Running Tests

### Via Xcode
- Press `Cmd+U` to run all tests
- Or use Product → Test menu

### Via Command Line
```bash
xcodebuild test \
  -project ScreenTranslate.xcodeproj \
  -scheme ScreenTranslate \
  -destination 'platform=macOS'
```

## Test Coverage Goals

- [x] KeyboardShortcut model
- [x] Error types (ScreenTranslateError, TextTranslationError)
- [x] TranslationFlowPhase
- [x] ShortcutRecordingType enum
- [ ] SettingsViewModel (requires @MainActor setup)
- [ ] Coordinator classes (requires dependency injection)
- [ ] TranslationService (requires mocking)

## Adding New Tests

When adding new tests:

1. Follow the `XCTestCase` pattern
2. Use `MARK:` comments to organize test sections
3. Name test methods descriptively: `test<What>_<Condition>_<ExpectedResult>`
4. For async tests, use `async` test methods

Example:
```swift
func testTranslate_WhenTextIsEmpty_ReturnsEmptyResult() async throws {
    // Arrange
    let service = TranslationService.shared

    // Act
    let result = try await service.translate(
        segments: [],
        to: "zh-Hans",
        preferredEngine: .apple,
        from: nil
    )

    // Assert
    XCTAssertTrue(result.isEmpty)
}
```

## Mocking Strategy

For services that require external dependencies (API calls, accessibility), use protocol-based mocking:

```swift
// Define a mock service
final class MockTranslationService: TranslationServicing {
    var mockResult: [BilingualSegment] = []
    var mockError: Error?

    func translate(...) async throws -> [BilingualSegment] {
        if let error = mockError {
            throw error
        }
        return mockResult
    }
}
```
