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
        count = metrics.count

        let sortedDurations = metrics.map(\.durationMilliseconds).sorted()
        p50Milliseconds = Self.percentile(sortedDurations, percentile: 0.50)
        p95Milliseconds = Self.percentile(sortedDurations, percentile: 0.95)
        maxMilliseconds = sortedDurations.last ?? 0
        failureCount = metrics.filter { !$0.success }.count
    }

    private static func percentile(_ sortedValues: [Double], percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }

        let clampedPercentile = max(0, min(1, percentile))
        let rank = (Double(sortedValues.count) * clampedPercentile).rounded(.up)
        let index = max(0, min(sortedValues.count - 1, Int(rank) - 1))
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
        summary.stage == stage
            && summary.p95Milliseconds <= p95Milliseconds
            && summary.failureCount <= maxFailureCount
    }
}
