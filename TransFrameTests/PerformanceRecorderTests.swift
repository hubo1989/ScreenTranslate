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
            PerformanceMetric(
                stage: .render,
                operationID: UUID(),
                duration: 0.25,
                memoryDeltaBytes: 0,
                success: true,
                errorCategory: nil
            ),
            PerformanceMetric(
                stage: .render,
                operationID: UUID(),
                duration: 0.30,
                memoryDeltaBytes: 0,
                success: true,
                errorCategory: nil
            )
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
