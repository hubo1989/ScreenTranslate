//
//  TranslationResultBundle.swift
//  ScreenTranslate
//
//  Bundle containing results from multiple translation engines
//

import Foundation

/// Result from a single translation engine
struct EngineResult: Sendable, Identifiable {
    let engine: EngineIdentifier
    let segments: [BilingualSegment]
    let latency: TimeInterval
    let error: Error?
    let id: UUID

    init(
        engine: EngineIdentifier,
        segments: [BilingualSegment],
        latency: TimeInterval,
        error: Error? = nil
    ) {
        self.id = UUID()
        self.engine = engine
        self.segments = segments
        self.latency = latency
        self.error = error
    }

    var isSuccess: Bool {
        error == nil && !segments.isEmpty
    }

    static func failed(engine: EngineIdentifier, error: Error, latency: TimeInterval = 0) -> EngineResult {
        EngineResult(
            engine: engine,
            segments: [],
            latency: latency,
            error: error
        )
    }
}

/// Bundle containing results from multiple translation engines
struct TranslationResultBundle: Sendable {
    let results: [EngineResult]
    let primaryEngine: EngineIdentifier
    let selectionMode: EngineSelectionMode
    let scene: TranslationScene?
    let timestamp: Date

    init(
        results: [EngineResult],
        primaryEngine: EngineIdentifier,
        selectionMode: EngineSelectionMode,
        scene: TranslationScene? = nil,
        timestamp: Date = Date()
    ) {
        self.results = results
        self.primaryEngine = primaryEngine
        self.selectionMode = selectionMode
        self.scene = scene
        self.timestamp = timestamp
    }

    var primaryResult: [BilingualSegment] {
        results.first { $0.engine == primaryEngine && $0.isSuccess }?.segments ?? []
    }

    var hasErrors: Bool {
        results.contains { $0.error != nil }
    }

    var allFailed: Bool {
        results.allSatisfy { $0.error != nil }
    }

    var successfulEngines: [EngineIdentifier] {
        results.filter { $0.isSuccess }.map { $0.engine }
    }

    var failedEngines: [EngineIdentifier] {
        results.filter { !$0.isSuccess }.map { $0.engine }
    }

    func result(for engine: EngineIdentifier) -> EngineResult? {
        results.first { $0.engine == engine }
    }

    func segments(for engine: EngineIdentifier) -> [BilingualSegment]? {
        result(for: engine)?.segments
    }

    var averageLatency: TimeInterval {
        let successfulResults = results.filter { $0.isSuccess }
        guard !successfulResults.isEmpty else { return 0 }
        return successfulResults.map(\.latency).reduce(0, +) / Double(successfulResults.count)
    }

    static func single(
        engine: EngineIdentifier,
        segments: [BilingualSegment],
        latency: TimeInterval,
        selectionMode: EngineSelectionMode = .primaryWithFallback,
        scene: TranslationScene? = nil
    ) -> TranslationResultBundle {
        let result = EngineResult(
            engine: engine,
            segments: segments,
            latency: latency
        )
        return TranslationResultBundle(
            results: [result],
            primaryEngine: engine,
            selectionMode: selectionMode,
            scene: scene
        )
    }

    static func failed(
        engine: EngineIdentifier,
        error: Error,
        selectionMode: EngineSelectionMode = .primaryWithFallback,
        scene: TranslationScene? = nil
    ) -> TranslationResultBundle {
        let result = EngineResult.failed(engine: engine, error: error)
        return TranslationResultBundle(
            results: [result],
            primaryEngine: engine,
            selectionMode: selectionMode,
            scene: scene
        )
    }
}

// MARK: - Error Types for Bundle

/// Errors specific to multi-engine translation
enum MultiEngineError: LocalizedError, Sendable {
    /// All engines failed
    case allEnginesFailed([Error])

    /// No engines configured
    case noEnginesConfigured

    /// Primary engine not available
    case primaryNotAvailable(TranslationEngineType)

    /// No results available
    case noResults

    var errorDescription: String? {
        switch self {
        case .allEnginesFailed(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: "; ")
            return NSLocalizedString(
                "multiengine.error.all_failed",
                comment: "All translation engines failed"
            ) + ": " + errorMessages
        case .noEnginesConfigured:
            return NSLocalizedString(
                "multiengine.error.no_engines",
                comment: "No translation engines are configured"
            )
        case .primaryNotAvailable(let engine):
            return String(
                format: NSLocalizedString(
                    "multiengine.error.primary_unavailable",
                    comment: "Primary engine %@ is not available"
                ),
                engine.localizedName
            )
        case .noResults:
            return NSLocalizedString(
                "multiengine.error.no_results",
                comment: "No translation results available"
            )
        }
    }
}
