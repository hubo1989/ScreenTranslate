import Foundation

enum DisplayFreshnessPolicy: Sendable, Equatable {
    case cached
    case alwaysRefresh
    case refreshIfOlderThan(TimeInterval)
}

actor CapturePipeline {
    static let shared = CapturePipeline()

    private let recorder: PerformanceRecorder
    private var lastDisplayRefresh: Date?

    init(recorder: PerformanceRecorder = .shared) {
        self.recorder = recorder
    }

    func verifyPermission(
        context: PipelineContext,
        _ checkPermission: @Sendable () async -> Bool
    ) async throws {
        let allowed: Bool
        do {
            allowed = try await recorder.measure(stage: .permission, operationID: context.operationID) {
                try Task.checkCancellation()
                return await checkPermission()
            }
        } catch {
            throw PipelineError(stage: .permission, error: error)
        }

        guard allowed else {
            throw TransFrameError.permissionDenied
        }
    }

    func lookupDisplay<T: Sendable>(
        context: PipelineContext,
        freshness: DisplayFreshnessPolicy = .refreshIfOlderThan(2),
        refresh: @Sendable () async -> Void,
        lookup: @Sendable () async throws -> T
    ) async throws -> T {
        let refreshNeeded = shouldRefresh(freshness: freshness)
        do {
            let value = try await recorder.measure(stage: .displayLookup, operationID: context.operationID) {
                try Task.checkCancellation()
                if refreshNeeded {
                    await refresh()
                }
                return try await lookup()
            }
            if refreshNeeded {
                lastDisplayRefresh = Date()
            }
            return value
        } catch let error as TransFrameError {
            throw error
        } catch {
            throw PipelineError(stage: .displayLookup, error: error)
        }
    }

    func capture<T: Sendable>(
        context: PipelineContext,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        do {
            return try await recorder.measure(stage: .capture, operationID: context.operationID) {
                try Task.checkCancellation()
                return try await operation()
            }
        } catch let error as TransFrameError {
            throw error
        } catch {
            throw PipelineError(stage: .capture, error: error)
        }
    }

    private func shouldRefresh(freshness: DisplayFreshnessPolicy) -> Bool {
        switch freshness {
        case .cached:
            return false
        case .alwaysRefresh:
            return true
        case .refreshIfOlderThan(let maxAge):
            guard let lastDisplayRefresh else { return true }
            return Date().timeIntervalSince(lastDisplayRefresh) > maxAge
        }
    }
}
