import CoreGraphics
import Foundation

struct PipelineContext: Sendable, Equatable {
    let operationID: UUID
    let startedAt: Date

    init(operationID: UUID = UUID(), startedAt: Date = Date()) {
        self.operationID = operationID
        self.startedAt = startedAt
    }

    var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}

enum PipelineError: LocalizedError, Sendable, Equatable {
    case noTextFound
    case analysisFailed(String)
    case translationFailed(String)
    case renderFailed(String)
    case cancelled

    var category: PipelineErrorCategory {
        switch self {
        case .noTextFound, .analysisFailed:
            return .analysis
        case .translationFailed:
            return .translation
        case .renderFailed:
            return .render
        case .cancelled:
            return .cancelled
        }
    }

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text found"
        case .analysisFailed(let message), .translationFailed(let message), .renderFailed(let message):
            return message
        case .cancelled:
            return "Cancelled"
        }
    }

    init(stage: PerformanceStage, error: Error) {
        if error is CancellationError {
            self = .cancelled
            return
        }

        if let pipelineError = error as? PipelineError {
            self = pipelineError
            return
        }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        switch stage {
        case .analysis:
            self = .analysisFailed(message)
        case .translation:
            self = .translationFailed(message)
        case .render:
            self = .renderFailed(message)
        default:
            self = .analysisFailed(message)
        }
    }
}

