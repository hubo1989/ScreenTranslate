# Performance Pipeline Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a measurable, staged performance pipeline architecture for TransFrame and use it to optimize capture, analysis, translation/rendering, history persistence, and validation gates.

**Architecture:** Add a lightweight `Services/Performance` foundation first, then introduce `CapturePipeline`, `AnalysisPipeline`, and `TranslationRenderPipeline` behind existing coordinators/controllers. Existing UI entry points remain stable while heavy work moves behind actor-backed services with metrics, cancellation, and benchmark coverage.

**Tech Stack:** Swift 6, Swift concurrency actors, XCTest, OSLog signpost, ScreenCaptureKit, Vision, AppKit/CoreGraphics, existing Xcode filesystem-synchronized groups.

---

## File Structure

Create:

- `TransFrame/Services/Performance/PerformanceMetric.swift`: value types for stages, metrics, budgets, and summaries.
- `TransFrame/Services/Performance/PerformanceRecorder.swift`: actor for measuring async work and aggregating summaries.
- `TransFrame/Services/Performance/MainThreadMonitor.swift`: lightweight main-thread stall sampler.
- `TransFrame/Services/Pipelines/CapturePipeline.swift`: capture facade over existing `CaptureManager`, `ScreenDetector`, and `WindowDetector`.
- `TransFrame/Services/Pipelines/AnalysisPipeline.swift`: OCR/VLM analysis facade with metrics and recovery.
- `TransFrame/Services/Pipelines/TranslationRenderPipeline.swift`: translation, render, and history facade.
- `TransFrame/Services/Pipelines/PipelineErrors.swift`: shared error categories and operation context.
- `TransFrameTests/PerformanceRecorderTests.swift`: unit tests for metrics and budgets.
- `TransFrameTests/PipelineSmokeTests.swift`: fixture and mock-based pipeline smoke/performance tests.

Modify:

- `TransFrame/Features/Capture/CaptureManager.swift`: remove unconditional display-cache invalidation path after `CapturePipeline` owns freshness policy.
- `TransFrame/Services/PaddleOCREngine.swift`: replace blocking process wait/read with cancellable async process runner.
- `TransFrame/Services/HistoryStore.swift`: split thumbnail generation/encoding from main actor publication.
- `TransFrame/Features/TranslationFlow/TranslationFlowController.swift`: call analysis and translation/render pipelines.
- `TransFrame/Features/TextTranslation/TextTranslationFlow.swift`: route bundle translation through `TranslationRenderPipeline` translation-only mode.
- `TransFrame/Features/Preview/PreviewViewModel+Export.swift`: route export/copy heavy work through pipeline or detached worker.
- `TransFrame/Services/TextInsertService.swift`: remove unused `charString`.
- `TransFrame/Features/Settings/SettingsViewModel.swift`: remove unused `oldValue`.
- `TransFrame.xcodeproj/project.pbxproj`: add Run Script output path or make script dependency-aware.
- `run_tests.sh`: update current project/scheme and add performance smoke mode.
- `TransFrameTests/README.md`: update test target status and commands.

Because the project uses Xcode filesystem-synchronized groups, adding Swift files under `TransFrame/` and `TransFrameTests/` should not require manual source phase edits.

## Task 1: Baseline Cleanup And Test Script

**Files:**
- Modify: `TransFrame/Services/TextInsertService.swift`
- Modify: `TransFrame/Features/Settings/SettingsViewModel.swift`
- Modify: `run_tests.sh`
- Modify: `TransFrameTests/README.md`
- Modify: `TransFrame.xcodeproj/project.pbxproj`

- [ ] **Step 1: Remove `TextInsertService` unused variable**

In `TransFrame/Services/TextInsertService.swift`, inside `typeCharacter(_:source:)`, delete this line:

```swift
let charString = String(character)
```

- [ ] **Step 2: Remove `SettingsViewModel` unused variable**

In `TransFrame/Features/Settings/SettingsViewModel.swift`, locate the setter block that declares:

```swift
let oldValue = settings.vlmProvider
```

Delete that line if the value is not used. Keep the surrounding provider-change logic intact.

- [ ] **Step 3: Replace `run_tests.sh` with current commands**

Use this complete script:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT="TransFrame.xcodeproj"
SCHEME="TransFrame"
DESTINATION="platform=macOS"

if [[ "${1:-}" == "--performance" ]]; then
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:TransFrameTests/PipelineSmokeTests \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY=""
else
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY=""
fi
```

- [ ] **Step 4: Update test README**

Change `TransFrameTests/README.md` so it says the project has a `TransFrameTests` target, and document:

```bash
./run_tests.sh
./run_tests.sh --performance
```

- [ ] **Step 5: Fix Run Script build phase warning**

In `TransFrame.xcodeproj/project.pbxproj`, update shell phase `SC000020` by adding an output path:

```pbxproj
outputPaths = (
  "$(DERIVED_FILE_DIR)/TransFrameFrameworkResign.stamp",
);
```

Append this line to the shell script after the framework loop:

```sh
mkdir -p "${DERIVED_FILE_DIR}"
touch "${DERIVED_FILE_DIR}/TransFrameFrameworkResign.stamp"
```

- [ ] **Step 6: Verify cleanup**

Run:

```bash
./run_tests.sh
```

Expected: `** TEST SUCCEEDED **` and no unused-variable warnings for `charString` or `oldValue`.

- [ ] **Step 7: Commit**

```bash
git add TransFrame/Services/TextInsertService.swift TransFrame/Features/Settings/SettingsViewModel.swift run_tests.sh TransFrameTests/README.md TransFrame.xcodeproj/project.pbxproj
git commit -m "chore: refresh test script and clear baseline warnings"
```

## Task 2: Performance Core Types

**Files:**
- Create: `TransFrame/Services/Performance/PerformanceMetric.swift`
- Create: `TransFrame/Services/Performance/PerformanceRecorder.swift`
- Create: `TransFrameTests/PerformanceRecorderTests.swift`

- [ ] **Step 1: Add failing tests**

Create `TransFrameTests/PerformanceRecorderTests.swift`:

```swift
import XCTest
@testable import TransFrame

final class PerformanceRecorderTests: XCTestCase {
    func testSummaryComputesP50AndP95() {
        let metrics = (1...20).map {
            PerformanceMetric(
                stage: .translation,
                operationID: UUID(),
                duration: Double($0) / 1000.0,
                memoryDeltaBytes: 0,
                success: true,
                errorCategory: nil
            )
        }

        let summary = PerformanceSummary(stage: .translation, metrics: metrics)

        XCTAssertEqual(summary.count, 20)
        XCTAssertEqual(summary.p50Milliseconds, 10.0, accuracy: 0.1)
        XCTAssertEqual(summary.p95Milliseconds, 19.0, accuracy: 0.1)
    }

    func testBudgetFailureWhenP95ExceedsLimit() {
        let metrics = [
            PerformanceMetric(stage: .render, operationID: UUID(), duration: 0.25, memoryDeltaBytes: 0, success: true, errorCategory: nil),
            PerformanceMetric(stage: .render, operationID: UUID(), duration: 0.30, memoryDeltaBytes: 0, success: true, errorCategory: nil)
        ]
        let summary = PerformanceSummary(stage: .render, metrics: metrics)
        let budget = PerformanceBudget(stage: .render, p95Milliseconds: 200)

        XCTAssertFalse(budget.allows(summary))
    }

    func testRecorderMeasuresAsyncOperation() async throws {
        let recorder = PerformanceRecorder()
        let result = try await recorder.measure(stage: .analysis, operationID: UUID()) {
            try await Task.sleep(for: .milliseconds(5))
            return "ok"
        }

        XCTAssertEqual(result, "ok")
        let summaries = await recorder.summaries()
        XCTAssertEqual(summaries[.analysis]?.count, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' -only-testing:TransFrameTests/PerformanceRecorderTests CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""
```

Expected: compile failure because `PerformanceMetric`, `PerformanceSummary`, `PerformanceBudget`, and `PerformanceRecorder` do not exist.

- [ ] **Step 3: Add metric types**

Create `TransFrame/Services/Performance/PerformanceMetric.swift`:

```swift
import Foundation

enum PerformanceStage: String, Codable, CaseIterable, Sendable, Hashable {
    case permission
    case displayLookup
    case capture
    case previewHandoff
    case analysis
    case translation
    case render
    case history
    case export
    case textSelection
    case textInsertion
}

enum PipelineErrorCategory: String, Codable, Sendable, Hashable {
    case permission
    case capture
    case analysis
    case translation
    case render
    case history
    case cancelled
    case unknown
}

struct PerformanceMetric: Sendable, Equatable {
    let stage: PerformanceStage
    let operationID: UUID
    let duration: TimeInterval
    let memoryDeltaBytes: Int64
    let success: Bool
    let errorCategory: PipelineErrorCategory?

    var durationMilliseconds: Double {
        duration * 1000
    }
}

struct PerformanceSummary: Sendable, Equatable {
    let stage: PerformanceStage
    let count: Int
    let p50Milliseconds: Double
    let p95Milliseconds: Double
    let maxMilliseconds: Double
    let failureCount: Int

    init(stage: PerformanceStage, metrics: [PerformanceMetric]) {
        self.stage = stage
        self.count = metrics.count
        let sorted = metrics.map(\.durationMilliseconds).sorted()
        self.p50Milliseconds = Self.percentile(sorted, percentile: 0.50)
        self.p95Milliseconds = Self.percentile(sorted, percentile: 0.95)
        self.maxMilliseconds = sorted.last ?? 0
        self.failureCount = metrics.filter { !$0.success }.count
    }

    private static func percentile(_ sortedValues: [Double], percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let clamped = max(0, min(1, percentile))
        let index = Int((Double(sortedValues.count - 1) * clamped).rounded())
        return sortedValues[index]
    }
}

struct PerformanceBudget: Sendable, Equatable {
    let stage: PerformanceStage
    let p95Milliseconds: Double
    let maxFailureCount: Int

    init(stage: PerformanceStage, p95Milliseconds: Double, maxFailureCount: Int = 0) {
        self.stage = stage
        self.p95Milliseconds = p95Milliseconds
        self.maxFailureCount = maxFailureCount
    }

    func allows(_ summary: PerformanceSummary) -> Bool {
        summary.p95Milliseconds <= p95Milliseconds && summary.failureCount <= maxFailureCount
    }
}
```

- [ ] **Step 4: Add recorder actor**

Create `TransFrame/Services/Performance/PerformanceRecorder.swift`:

```swift
import Foundation
import os
import os.signpost

actor PerformanceRecorder {
    static let shared = PerformanceRecorder()

    private let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "TransFrame",
        category: "PerformancePipeline"
    )
    private var metricsByStage: [PerformanceStage: [PerformanceMetric]] = [:]

    func record(_ metric: PerformanceMetric) {
        metricsByStage[metric.stage, default: []].append(metric)
    }

    func measure<T: Sendable>(
        stage: PerformanceStage,
        operationID: UUID,
        memoryBefore: Int64 = 0,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "PipelineStage", signpostID: signpostID, "%{public}s", stage.rawValue)
        let startedAt = ContinuousClock.now
        do {
            let value = try await operation()
            let duration = startedAt.duration(to: .now).timeInterval
            os_signpost(.end, log: log, name: "PipelineStage", signpostID: signpostID, "%{public}s", stage.rawValue)
            record(PerformanceMetric(stage: stage, operationID: operationID, duration: duration, memoryDeltaBytes: -memoryBefore, success: true, errorCategory: nil))
            return value
        } catch is CancellationError {
            let duration = startedAt.duration(to: .now).timeInterval
            os_signpost(.end, log: log, name: "PipelineStage", signpostID: signpostID, "%{public}s", stage.rawValue)
            record(PerformanceMetric(stage: stage, operationID: operationID, duration: duration, memoryDeltaBytes: -memoryBefore, success: false, errorCategory: .cancelled))
            throw error
        } catch {
            let duration = startedAt.duration(to: .now).timeInterval
            os_signpost(.end, log: log, name: "PipelineStage", signpostID: signpostID, "%{public}s", stage.rawValue)
            record(PerformanceMetric(stage: stage, operationID: operationID, duration: duration, memoryDeltaBytes: -memoryBefore, success: false, errorCategory: .unknown))
            throw error
        }
    }

    func summaries() -> [PerformanceStage: PerformanceSummary] {
        metricsByStage.mapValues { metrics in
            PerformanceSummary(stage: metrics.first?.stage ?? .capture, metrics: metrics)
        }
    }

    func reset() {
        metricsByStage.removeAll()
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
```

- [ ] **Step 5: Run tests**

Run the same `PerformanceRecorderTests` command. Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add TransFrame/Services/Performance TransFrameTests/PerformanceRecorderTests.swift
git commit -m "feat: add performance recorder core"
```

## Task 3: Pipeline Error And Operation Context

**Files:**
- Create: `TransFrame/Services/Pipelines/PipelineErrors.swift`
- Test: `TransFrameTests/PipelineSmokeTests.swift`

- [ ] **Step 1: Add tests for operation context and error mapping**

Create `TransFrameTests/PipelineSmokeTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import TransFrame

final class PipelineSmokeTests: XCTestCase {
    func testPipelineContextCreatesStableOperationID() {
        let context = PipelineOperationContext()
        XCTAssertEqual(context.operationID, context.operationID)
    }

    func testPipelineErrorMapsCancellation() {
        let error = PipelineError.cancelled
        XCTAssertEqual(error.category, .cancelled)
        XCTAssertNotNil(error.errorDescription)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' -only-testing:TransFrameTests/PipelineSmokeTests CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""
```

Expected: compile failure because `PipelineOperationContext` and `PipelineError` do not exist.

- [ ] **Step 3: Add pipeline shared types**

Create `TransFrame/Services/Pipelines/PipelineErrors.swift`:

```swift
import Foundation

struct PipelineOperationContext: Sendable, Equatable {
    let operationID: UUID
    let startedAt: Date

    init(operationID: UUID = UUID(), startedAt: Date = Date()) {
        self.operationID = operationID
        self.startedAt = startedAt
    }
}

enum PipelineError: LocalizedError, Sendable, Equatable {
    case cancelled
    case noTextFound
    case stageFailed(stage: PerformanceStage, category: PipelineErrorCategory, message: String)

    var category: PipelineErrorCategory {
        switch self {
        case .cancelled:
            return .cancelled
        case .noTextFound:
            return .analysis
        case .stageFailed(_, let category, _):
            return category
        }
    }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return String(localized: "translationFlow.error.cancelled")
        case .noTextFound:
            return String(localized: "translationFlow.error.noTextFound")
        case .stageFailed(_, _, let message):
            return message
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run the same `PipelineSmokeTests` command. Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add TransFrame/Services/Pipelines/PipelineErrors.swift TransFrameTests/PipelineSmokeTests.swift
git commit -m "feat: add pipeline operation context"
```

## Task 4: TranslationRenderPipeline With Mockable Dependencies

**Files:**
- Create: `TransFrame/Services/Pipelines/TranslationRenderPipeline.swift`
- Modify: `TransFrameTests/PipelineSmokeTests.swift`

- [ ] **Step 1: Add tests for translation-only pipeline**

Append to `PipelineSmokeTests`:

```swift
func testTranslationRenderPipelineUsesBundlePrimaryResult() async throws {
    let provider = MockPipelineTranslationService()
    let pipeline = TranslationRenderPipeline(
        translationService: provider,
        recorder: PerformanceRecorder()
    )
    let request = TranslationRenderRequest.translationOnly(
        text: "Hello",
        targetLanguage: "zh-Hans",
        sourceLanguage: "en",
        preferredEngine: .apple
    )

    let result = try await pipeline.run(request)

    XCTAssertEqual(result.translatedText, "你好")
    XCTAssertEqual(result.bundle.successfulEngines, [.apple])
}

private actor MockPipelineTranslationService: TranslationServicing {
    func translate(
        segments: [String],
        to targetLanguage: String,
        preferredEngine: TranslationEngineType,
        from sourceLanguage: String?,
        scene: TranslationScene?,
        mode: EngineSelectionMode,
        fallbackEnabled: Bool,
        parallelEngines: [TranslationEngineType],
        sceneBindings: [TranslationScene: SceneEngineBinding]
    ) async throws -> [BilingualSegment] {
        [
            BilingualSegment(
                original: TextSegment(text: segments[0], boundingBox: .zero, confidence: 1),
                translated: "你好",
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        ]
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run `PipelineSmokeTests`. Expected: compile failure because `TranslationRenderPipeline` and request/result types do not exist.

- [ ] **Step 3: Add pipeline implementation**

Create `TransFrame/Services/Pipelines/TranslationRenderPipeline.swift`:

```swift
import CoreGraphics
import Foundation

struct TranslationRenderRequest: Sendable {
    let context: PipelineOperationContext
    let segments: [String]
    let targetLanguage: String
    let sourceLanguage: String?
    let preferredEngine: TranslationEngineType
    let scene: TranslationScene?
    let mode: EngineSelectionMode
    let fallbackEnabled: Bool
    let parallelEngines: [TranslationEngineType]
    let sceneBindings: [TranslationScene: SceneEngineBinding]
    let originalImage: CGImage?

    static func translationOnly(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?,
        preferredEngine: TranslationEngineType,
        context: PipelineOperationContext = PipelineOperationContext()
    ) -> TranslationRenderRequest {
        TranslationRenderRequest(
            context: context,
            segments: [text],
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
            preferredEngine: preferredEngine,
            scene: .textSelection,
            mode: .primaryWithFallback,
            fallbackEnabled: true,
            parallelEngines: [],
            sceneBindings: [:],
            originalImage: nil
        )
    }
}

struct TranslationRenderResult: Sendable {
    let bundle: TranslationResultBundle
    let renderedImage: CGImage?

    var translatedText: String {
        bundle.results.first(where: { $0.isSuccess })?
            .segments
            .map(\.translated)
            .joined(separator: "\n") ?? ""
    }
}

actor TranslationRenderPipeline {
    private let translationService: any TranslationServicing
    private let recorder: PerformanceRecorder

    init(
        translationService: any TranslationServicing = TranslationService.shared,
        recorder: PerformanceRecorder = .shared
    ) {
        self.translationService = translationService
        self.recorder = recorder
    }

    func run(_ request: TranslationRenderRequest) async throws -> TranslationRenderResult {
        let bundle = try await recorder.measure(stage: .translation, operationID: request.context.operationID) {
            try await translationService.translateBundle(
                segments: request.segments,
                to: request.targetLanguage,
                preferredEngine: request.preferredEngine,
                from: request.sourceLanguage,
                scene: request.scene,
                mode: request.mode,
                fallbackEnabled: request.fallbackEnabled,
                parallelEngines: request.parallelEngines,
                sceneBindings: request.sceneBindings
            )
        }

        return TranslationRenderResult(bundle: bundle, renderedImage: nil)
    }
}
```

- [ ] **Step 4: Run tests**

Run `PipelineSmokeTests`. Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add TransFrame/Services/Pipelines/TranslationRenderPipeline.swift TransFrameTests/PipelineSmokeTests.swift
git commit -m "feat: add translation render pipeline shell"
```

## Task 5: AnalysisPipeline Shell And Prompt Leakage Recovery

**Files:**
- Create: `TransFrame/Services/Pipelines/AnalysisPipeline.swift`
- Modify: `TransFrameTests/PipelineSmokeTests.swift`

- [ ] **Step 1: Add mock analysis tests**

Append to `PipelineSmokeTests`:

```swift
func testAnalysisPipelineReturnsRecoveredOCRWhenPrimaryLeaksPrompt() async throws {
    let primary = MockScreenAnalyzer(result: ScreenAnalysisResult(
        segments: [
            TextSegment(text: "\"segments\": [{\"boundingBox\": {\"x\": 0}}]", boundingBox: .zero, confidence: 1)
        ],
        imageSize: CGSize(width: 10, height: 10)
    ))
    let fallback = MockOCRAnalyzer(result: OCRResult(
        observations: [
            OCRText(text: "Hello", boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), confidence: 1)
        ],
        imageSize: CGSize(width: 10, height: 10)
    ))
    let pipeline = AnalysisPipeline(primaryAnalyzer: primary, fallbackOCR: fallback, recorder: PerformanceRecorder())

    let result = try await pipeline.analyze(image: Self.makeTestImage())

    XCTAssertEqual(result.analysis.fullText, "Hello")
    XCTAssertTrue(result.fallbackUsed)
}

private actor MockScreenAnalyzer: ScreenAnalyzing {
    let result: ScreenAnalysisResult
    init(result: ScreenAnalysisResult) { self.result = result }
    func analyze(image: CGImage) async throws -> ScreenAnalysisResult { result }
}

private actor MockOCRAnalyzer: OCRAnalyzing {
    let result: OCRResult
    init(result: OCRResult) { self.result = result }
    func recognize(_ image: CGImage) async throws -> OCRResult { result }
}

private static func makeTestImage() -> CGImage {
    let context = CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    return context.makeImage()!
}
```

- [ ] **Step 2: Run tests to verify failure**

Run `PipelineSmokeTests`. Expected: compile failure for missing analysis types.

- [ ] **Step 3: Add AnalysisPipeline**

Create `TransFrame/Services/Pipelines/AnalysisPipeline.swift`:

```swift
import CoreGraphics
import Foundation

protocol ScreenAnalyzing: Sendable {
    func analyze(image: CGImage) async throws -> ScreenAnalysisResult
}

protocol OCRAnalyzing: Sendable {
    func recognize(_ image: CGImage) async throws -> OCRResult
}

extension ScreenCoderEngine: ScreenAnalyzing {}

extension OCREngine: OCRAnalyzing {}

struct AnalysisPipelineResult: Sendable {
    let analysis: ScreenAnalysisResult
    let fallbackUsed: Bool
}

actor AnalysisPipeline {
    private let primaryAnalyzer: any ScreenAnalyzing
    private let fallbackOCR: any OCRAnalyzing
    private let recorder: PerformanceRecorder

    init(
        primaryAnalyzer: any ScreenAnalyzing = ScreenCoderEngine.shared,
        fallbackOCR: any OCRAnalyzing = OCREngine.shared,
        recorder: PerformanceRecorder = .shared
    ) {
        self.primaryAnalyzer = primaryAnalyzer
        self.fallbackOCR = fallbackOCR
        self.recorder = recorder
    }

    func analyze(
        image: CGImage,
        context: PipelineOperationContext = PipelineOperationContext()
    ) async throws -> AnalysisPipelineResult {
        let initial = try await recorder.measure(stage: .analysis, operationID: context.operationID) {
            try await primaryAnalyzer.analyze(image: image)
        }

        guard initial.containsOnlyPromptLeakage else {
            return AnalysisPipelineResult(analysis: initial.filteredForTranslation(), fallbackUsed: false)
        }

        let fallback = try await recorder.measure(stage: .analysis, operationID: context.operationID) {
            try await fallbackOCR.recognize(image)
        }
        let recovered = ScreenAnalysisResult(ocrResult: fallback).filteredForTranslation()
        return AnalysisPipelineResult(
            analysis: recovered.segments.isEmpty ? initial.filteredForTranslation() : recovered,
            fallbackUsed: !recovered.segments.isEmpty
        )
    }
}
```

- [ ] **Step 4: Run tests**

Run `PipelineSmokeTests`. Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add TransFrame/Services/Pipelines/AnalysisPipeline.swift TransFrameTests/PipelineSmokeTests.swift
git commit -m "feat: add analysis pipeline shell"
```

## Task 6: CapturePipeline Shell

**Files:**
- Create: `TransFrame/Services/Pipelines/CapturePipeline.swift`
- Modify: `TransFrameTests/PipelineSmokeTests.swift`

- [ ] **Step 1: Add capture pipeline mock test**

Append to `PipelineSmokeTests`:

```swift
func testCapturePipelineRecordsCaptureMetric() async throws {
    let recorder = PerformanceRecorder()
    let pipeline = CapturePipeline(capturer: MockCapturer(image: Self.makeTestImage()), recorder: recorder)

    let result = try await pipeline.capture(.fullScreen)

    XCTAssertEqual(result.screenshot.image.width, 10)
    let summaries = await recorder.summaries()
    XCTAssertEqual(summaries[.capture]?.count, 1)
}

private actor MockCapturer: ScreenCapturing {
    let image: CGImage
    init(image: CGImage) { self.image = image }
    func capture(_ request: CapturePipelineRequest) async throws -> Screenshot {
        Screenshot(image: image, captureDate: Date(), sourceDisplay: DisplayInfo.mainFallback)
    }
}
```

- [ ] **Step 2: Add fallback display helper for tests**

If `DisplayInfo` has no easy test initializer, add this in `PipelineSmokeTests.swift` test-only extension:

```swift
private extension DisplayInfo {
    static var mainFallback: DisplayInfo {
        DisplayInfo(
            id: CGMainDisplayID(),
            name: "Test Display",
            frame: CGRect(x: 0, y: 0, width: 10, height: 10),
            scaleFactor: 1,
            isPrimary: true
        )
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

Run `PipelineSmokeTests`. Expected: compile failure for missing capture pipeline types.

- [ ] **Step 4: Add CapturePipeline**

Create `TransFrame/Services/Pipelines/CapturePipeline.swift`:

```swift
import CoreGraphics
import Foundation

enum CapturePipelineRequest: Sendable, Equatable {
    case fullScreen
    case region(CGRect, DisplayInfo)
}

protocol ScreenCapturing: Sendable {
    func capture(_ request: CapturePipelineRequest) async throws -> Screenshot
}

actor CaptureManagerAdapter: ScreenCapturing {
    func capture(_ request: CapturePipelineRequest) async throws -> Screenshot {
        switch request {
        case .fullScreen:
            return try await CaptureManager.shared.captureFullScreen()
        case .region(let rect, let display):
            return try await CaptureManager.shared.captureRegion(rect, from: display)
        }
    }
}

struct CapturePipelineResult: Sendable {
    let screenshot: Screenshot
}

actor CapturePipeline {
    private let capturer: any ScreenCapturing
    private let recorder: PerformanceRecorder

    init(capturer: any ScreenCapturing = CaptureManagerAdapter(), recorder: PerformanceRecorder = .shared) {
        self.capturer = capturer
        self.recorder = recorder
    }

    func capture(
        _ request: CapturePipelineRequest,
        context: PipelineOperationContext = PipelineOperationContext()
    ) async throws -> CapturePipelineResult {
        let screenshot = try await recorder.measure(stage: .capture, operationID: context.operationID) {
            try await capturer.capture(request)
        }
        return CapturePipelineResult(screenshot: screenshot)
    }
}
```

- [ ] **Step 5: Run tests**

Run `PipelineSmokeTests`. Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add TransFrame/Services/Pipelines/CapturePipeline.swift TransFrameTests/PipelineSmokeTests.swift
git commit -m "feat: add capture pipeline shell"
```

## Task 7: Integrate TextTranslationFlow With TranslationRenderPipeline

**Files:**
- Modify: `TransFrame/Features/TextTranslation/TextTranslationFlow.swift`
- Modify: `TransFrameTests/TranslationServicePipelineTests.swift`

- [ ] **Step 1: Add regression test for existing TextTranslationFlow behavior**

Add a test that uses the existing mock service and asserts `lastResult` and `currentPhase` still update after routing through the pipeline.

- [ ] **Step 2: Inject TranslationRenderPipeline**

In `TextTranslationFlow`, add:

```swift
private let translationPipeline: TranslationRenderPipeline
```

Update initializer:

```swift
init(
    service: any TranslationServicing = TranslationService.shared,
    translationPipeline: TranslationRenderPipeline? = nil
) {
    self.translationService = service
    self.translationPipeline = translationPipeline ?? TranslationRenderPipeline(translationService: service)
}
```

- [ ] **Step 3: Replace direct `translationService.translateBundle` call**

Inside the task body, build:

```swift
let request = TranslationRenderRequest(
    context: PipelineOperationContext(),
    segments: [trimmedText],
    targetLanguage: effectiveTargetLanguage,
    sourceLanguage: effectiveSourceLanguage,
    preferredEngine: effectiveEngine,
    scene: config.scene,
    mode: config.mode,
    fallbackEnabled: config.fallbackEnabled,
    parallelEngines: config.parallelEngines,
    sceneBindings: config.sceneBindings,
    originalImage: nil
)
let pipelineResult = try await translationPipeline.run(request)
let bundle = pipelineResult.bundle
```

Keep downstream result assembly unchanged.

- [ ] **Step 4: Run tests**

Run:

```bash
xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' -only-testing:TransFrameTests/TranslationServicePipelineTests CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add TransFrame/Features/TextTranslation/TextTranslationFlow.swift TransFrameTests/TranslationServicePipelineTests.swift
git commit -m "refactor: route text translation through pipeline"
```

## Task 8: Integrate TranslationFlowController With Analysis And Render Pipelines

**Files:**
- Modify: `TransFrame/Features/TranslationFlow/TranslationFlowController.swift`
- Modify: `TransFrameTests/TranslationPipelineRegressionTests.swift`

- [ ] **Step 1: Add regression coverage for prompt leakage fallback**

Keep the existing `recoverAnalysisResultIfNeeded` test passing by retaining the static helper until migration is complete.

- [ ] **Step 2: Add pipeline properties**

In `TranslationFlowController`, add:

```swift
private let analysisPipeline = AnalysisPipeline()
private let translationRenderPipeline = TranslationRenderPipeline()
```

- [ ] **Step 3: Replace direct analysis block**

Replace direct `screenCoderEngine.analyze` and static recovery call with:

```swift
let context = PipelineOperationContext()
let analysisPipelineResult = try await analysisPipeline.analyze(image: image, context: context)
let analysisResult = analysisPipelineResult.analysis
```

- [ ] **Step 4: Replace direct translation service call**

Build a `TranslationRenderRequest` from `filteredAnalysisResult.segments.map(\.text)` and call `translationRenderPipeline.run(request)`. Keep mapping back from original segments to translated segments until `TranslationRenderPipeline` owns image render in a later task.

- [ ] **Step 5: Run translation tests**

Run:

```bash
xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' -only-testing:TransFrameTests/TranslationPipelineRegressionTests CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add TransFrame/Features/TranslationFlow/TranslationFlowController.swift TransFrameTests/TranslationPipelineRegressionTests.swift
git commit -m "refactor: route screenshot translation through pipelines"
```

## Task 9: Move History Thumbnail Work Off MainActor

**Files:**
- Modify: `TransFrame/Services/HistoryStore.swift`
- Test: `TransFrameTests/PipelineSmokeTests.swift`

- [ ] **Step 1: Extract thumbnail generator**

Create a nested nonisolated helper in `HistoryStore.swift`:

```swift
enum HistoryThumbnailGenerator {
    static func generate(from image: CGImage, maxSize: CGFloat, quality: CGFloat, maxDataSize: Int) -> Data? {
        // Move existing generateThumbnail body here unchanged.
    }
}
```

- [ ] **Step 2: Update `add(result:image:)`**

Make `add` publish text immediately and compute thumbnail in a task when image exists, or introduce `addAsync(result:image:)` used by pipelines. Keep the existing `add(result:image:)` signature for callers.

- [ ] **Step 3: Add fixture test for thumbnail size**

Use `Self.makeTestImage()` and assert generated thumbnail is not nil for a simple image.

- [ ] **Step 4: Run tests**

Run `PipelineSmokeTests` and full `./run_tests.sh`. Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add TransFrame/Services/HistoryStore.swift TransFrameTests/PipelineSmokeTests.swift
git commit -m "perf: move history thumbnail generation off main actor"
```

## Task 10: Cancellable PaddleOCR Process Runner

**Files:**
- Modify: `TransFrame/Services/PaddleOCREngine.swift`
- Test: `TransFrameTests/PipelineSmokeTests.swift`

- [ ] **Step 1: Add process runner helper**

In `PaddleOCREngine.swift`, replace `task.run(); task.waitUntilExit(); readDataToEndOfFile()` with an async helper:

```swift
private func runProcess(_ task: Process, stdoutPipe: Pipe, stderrPipe: Pipe) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (
                    String(data: stdoutData, encoding: .utf8) ?? "",
                    String(data: stderrData, encoding: .utf8) ?? "",
                    process.terminationStatus
                ))
            }
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    } onCancel: {
        if task.isRunning {
            task.terminate()
        }
    }
}
```

- [ ] **Step 2: Use helper in `executePaddleOCR`**

Replace the blocking run block with:

```swift
let processResult = try await runProcess(task, stdoutPipe: stdoutPipe, stderrPipe: stderrPipe)
var stdout = processResult.stdout
let stderr = processResult.stderr
let exitCode = processResult.exitCode
```

Keep existing stderr extraction and JSON parsing logic.

- [ ] **Step 3: Run OCR-related tests**

Run:

```bash
xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' -only-testing:TransFrameTests/GLMOCRVLMProviderTests CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""
```

Expected: tests pass.

- [ ] **Step 4: Commit**

```bash
git add TransFrame/Services/PaddleOCREngine.swift
git commit -m "perf: make paddleocr process execution cancellable"
```

## Task 11: Performance Smoke Gate

**Files:**
- Modify: `TransFrameTests/PipelineSmokeTests.swift`
- Modify: `run_tests.sh`

- [ ] **Step 1: Add smoke benchmark test**

Append:

```swift
func testPipelineSmokeBudgets() async throws {
    let recorder = PerformanceRecorder()
    let pipeline = TranslationRenderPipeline(
        translationService: MockPipelineTranslationService(),
        recorder: recorder
    )

    for _ in 0..<10 {
        _ = try await pipeline.run(.translationOnly(text: "Hello", targetLanguage: "zh-Hans", sourceLanguage: "en", preferredEngine: .apple))
    }

    let summary = try XCTUnwrap(await recorder.summaries()[.translation])
    let budget = PerformanceBudget(stage: .translation, p95Milliseconds: 150)
    XCTAssertTrue(budget.allows(summary), "translation mock P95 \(summary.p95Milliseconds)ms exceeded budget")
}
```

- [ ] **Step 2: Verify performance script**

Run:

```bash
./run_tests.sh --performance
```

Expected: `PipelineSmokeTests` pass and complete without network calls.

- [ ] **Step 3: Run full tests**

Run:

```bash
./run_tests.sh
```

Expected: full suite passes.

- [ ] **Step 4: Commit**

```bash
git add TransFrameTests/PipelineSmokeTests.swift run_tests.sh
git commit -m "test: add performance smoke gate"
```

## Task 12: Completion Verification

**Files:**
- Inspect all changed files.

- [ ] **Step 1: Check quality gate markers**

Run:

```bash
rg -n "TODO|FIXME|HACK|XXX|NOCOMMIT" TransFrame TransFrameTests docs/superpowers
```

Expected: no untracked quality gate markers from this work.

- [ ] **Step 2: Check secrets**

Run:

```bash
rg -n "api[_-]?key|token|secret|password" TransFrame TransFrameTests docs/superpowers -g '!*.strings'
```

Expected: only existing keychain/configuration references, no hardcoded real credentials.

- [ ] **Step 3: Run full tests**

Run:

```bash
./run_tests.sh
./run_tests.sh --performance
```

Expected: both pass.

- [ ] **Step 4: Inspect git diff**

Run:

```bash
git diff --stat
git diff --check
```

Expected: focused performance pipeline changes, no whitespace errors.

- [ ] **Step 5: Final commit if needed**

If verification fixes were required:

```bash
git add .
git commit -m "chore: verify performance pipeline optimization"
```

