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

typealias PipelineOperationContext = PipelineContext

enum PipelineError: LocalizedError, Sendable, Equatable {
    case noTextFound
    case captureFailed(String)
    case analysisFailed(String)
    case translationFailed(String)
    case renderFailed(String)
    case exportFailed(String)
    case cancelled

    var category: PipelineErrorCategory {
        switch self {
        case .captureFailed:
            return .capture
        case .noTextFound, .analysisFailed:
            return .analysis
        case .translationFailed:
            return .translation
        case .renderFailed:
            return .render
        case .exportFailed:
            return .export
        case .cancelled:
            return .cancelled
        }
    }

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text found"
        case .captureFailed(let message),
             .analysisFailed(let message),
             .translationFailed(let message),
             .renderFailed(let message),
             .exportFailed(let message):
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
        case .permission, .displayLookup, .capture:
            self = .captureFailed(message)
        case .analysis:
            self = .analysisFailed(message)
        case .translation:
            self = .translationFailed(message)
        case .render:
            self = .renderFailed(message)
        case .export:
            self = .exportFailed(message)
        default:
            self = .analysisFailed(message)
        }
    }
}
