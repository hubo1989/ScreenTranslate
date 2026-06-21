import Foundation

actor MainThreadMonitor {
    static let shared = MainThreadMonitor()

    private let recorder: PerformanceRecorder

    init(recorder: PerformanceRecorder = .shared) {
        self.recorder = recorder
    }

    func measureHandoff<T: Sendable>(
        operationID: UUID,
        _ operation: @MainActor @Sendable () throws -> T
    ) async throws -> T {
        try await recorder.measure(stage: .previewHandoff, operationID: operationID) {
            try await MainActor.run {
                try operation()
            }
        }
    }

    func sampleHandoffLatency(operationID: UUID = UUID()) async {
        try? await measureHandoff(operationID: operationID) {}
    }
}
