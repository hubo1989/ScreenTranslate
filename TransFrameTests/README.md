# TransFrame Unit Tests

This directory contains unit tests for the TransFrame application.

## Test Files

| File | Description |
|------|-------------|
| `KeyboardShortcutTests.swift` | Tests for keyboard shortcut model |
| `TransFrameErrorTests.swift` | Tests for error types |
| `TextTranslationErrorTests.swift` | Tests for translation errors and phases |
| `ShortcutRecordingTypeTests.swift` | Tests for shortcut recording enum |
| `TranslationServicePipelineTests.swift` | Tests for translation service orchestration |
| `TranslationPipelineRegressionTests.swift` | Regression tests for translation filtering and recovery |
| `GLMOCRVLMProviderTests.swift` | Tests for GLM/OpenAI-compatible VLM parsing |
| `ModelDiscoveryServiceTests.swift` | Tests for model list parsing |

## Test Target

The Xcode project has a `TransFrameTests` unit test target. New Swift test files placed in this directory are included by the filesystem-synchronized Xcode group.

## Running Tests

### Via Xcode
- Press `Cmd+U` to run all tests
- Or use Product → Test menu

### Via Command Line
```bash
./run_tests.sh
./run_tests.sh --performance
```

The `--performance` mode runs the lightweight performance smoke suite and avoids real network/API calls.

## Test Coverage Goals

- [x] KeyboardShortcut model
- [x] Error types (TransFrameError, TextTranslationError)
- [x] TranslationFlowPhase
- [x] ShortcutRecordingType enum
- [x] SettingsViewModel shortcut conflict checks
- [x] TranslationService pipeline behavior with mocks
- [ ] Coordinator classes (requires dependency injection)
- [ ] Performance pipeline smoke tests

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
