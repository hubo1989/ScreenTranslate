import AppKit
import Observation

/// 翻译流程阶段
enum TranslationFlowPhase: Sendable, Equatable {
    case idle
    case analyzing
    case translating
    case rendering
    case completed
    case failed(TranslationFlowError)

    var isProcessing: Bool {
        switch self {
        case .analyzing, .translating, .rendering:
            return true
        default:
            return false
        }
    }

    var localizedDescription: String {
        switch self {
        case .idle:
            return String(localized: "translationFlow.phase.idle")
        case .analyzing:
            return String(localized: "translationFlow.phase.analyzing")
        case .translating:
            return String(localized: "translationFlow.phase.translating")
        case .rendering:
            return String(localized: "translationFlow.phase.rendering")
        case .completed:
            return String(localized: "translationFlow.phase.completed")
        case .failed:
            return String(localized: "translationFlow.phase.failed")
        }
    }

    var progress: Double {
        switch self {
        case .idle: return 0.0
        case .analyzing: return 0.25
        case .translating: return 0.50
        case .rendering: return 0.75
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }
}

/// 翻译流程错误
enum TranslationFlowError: LocalizedError, Sendable, Equatable {
    case analysisFailure(String)
    case translationFailure(String)
    case renderingFailure(String)
    case cancelled
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .analysisFailure(let message):
            return String(localized: "translationFlow.error.analysis \(message)")
        case .translationFailure(let message):
            return String(localized: "translationFlow.error.translation \(message)")
        case .renderingFailure(let message):
            return String(localized: "translationFlow.error.rendering \(message)")
        case .cancelled:
            return String(localized: "translationFlow.error.cancelled")
        case .noTextFound:
            return String(localized: "translationFlow.error.noTextFound")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .analysisFailure:
            return String(localized: "translationFlow.recovery.analysis")
        case .translationFailure:
            return String(localized: "translationFlow.recovery.translation")
        case .renderingFailure:
            return String(localized: "translationFlow.recovery.rendering")
        case .cancelled:
            return nil
        case .noTextFound:
            return String(localized: "translationFlow.recovery.noTextFound")
        }
    }
}

/// 翻译流程结果
struct TranslationFlowResult: Sendable {
    let originalImage: CGImage
    let renderedImage: NSImage
    let segments: [BilingualSegment]
    let processingTime: TimeInterval
}

/// 翻译流程控制器 - 协调整个翻译流程
@MainActor
@Observable
final class TranslationFlowController {
    static let shared = TranslationFlowController()

    // MARK: - Observable State

    private(set) var currentPhase: TranslationFlowPhase = .idle
    private(set) var lastError: TranslationFlowError?
    private(set) var lastResult: TranslationFlowResult?

    // MARK: - Private

    private var currentTask: Task<Void, Never>?
    private let screenCoderEngine = ScreenCoderEngine.shared
    private let overlayRenderer = OverlayRenderer()

    private init() {}

    // MARK: - Public API

    func startTranslation(image: CGImage) {
        cancel()

        currentTask = Task {
            await performTranslation(image: image)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil

        if currentPhase.isProcessing {
            currentPhase = .failed(.cancelled)
            lastError = .cancelled
        }
    }

    func reset() {
        cancel()
        currentPhase = .idle
        lastError = nil
        lastResult = nil
    }

    // MARK: - Private Implementation

    private func performTranslation(image: CGImage) async {
        let startTime = Date()
        lastError = nil
        lastResult = nil

        // Show loading window immediately with original image
        await MainActor.run {
            BilingualResultWindowController.shared.showLoading(
                originalImage: image,
                message: String(localized: "bilingualResult.loading.analyzing")
            )
        }

        // Phase 1: 分析图像
        currentPhase = .analyzing

        let analysisResult: ScreenAnalysisResult
        do {
            try Task.checkCancellation()
            analysisResult = try await screenCoderEngine.analyze(image: image)

            if analysisResult.segments.isEmpty {
                throw TranslationFlowError.noTextFound
            }
        } catch is CancellationError {
            handleCancellation()
            return
        } catch let error as TranslationFlowError {
            handleError(error)
            return
        } catch {
            handleError(.analysisFailure(error.localizedDescription))
            return
        }

        // Phase 2: 翻译文本
        currentPhase = .translating

        let bilingualSegments: [BilingualSegment]
        do {
            try Task.checkCancellation()

            let settings = AppSettings.shared
            let targetLanguage = settings.translationTargetLanguage?.rawValue ?? "zh-Hans"
            let sourceLanguage = settings.translationSourceLanguage.rawValue
            let engine = settings.translationEngine

            let texts = analysisResult.segments.map { $0.text }

            if #available(macOS 13.0, *) {
                let translatedSegments = try await TranslationService.shared.translate(
                    segments: texts,
                    to: targetLanguage,
                    preferredEngine: engine,
                    from: sourceLanguage
                )
                
                // Merge bounding box info from VLM analysis back into translated segments
                bilingualSegments = zip(analysisResult.segments, translatedSegments).map { original, translated in
                    BilingualSegment(
                        segment: original,
                        translatedText: translated.translated,
                        sourceLanguage: translated.sourceLanguage,
                        targetLanguage: translated.targetLanguage
                    )
                }
            } else {
                throw TranslationFlowError.translationFailure("macOS 13.0+ required")
            }
        } catch is CancellationError {
            handleCancellation()
            return
        } catch let error as TranslationFlowError {
            handleError(error)
            return
        } catch {
            handleError(.translationFailure(error.localizedDescription))
            return
        }

        // Phase 3: 渲染结果
        currentPhase = .rendering

        do {
            try Task.checkCancellation()

            guard let renderedImage = overlayRenderer.render(image: image, segments: bilingualSegments) else {
                throw TranslationFlowError.renderingFailure("Failed to render overlay")
            }

            let processingTime = Date().timeIntervalSince(startTime)

            lastResult = TranslationFlowResult(
                originalImage: image,
                renderedImage: renderedImage,
                segments: bilingualSegments,
                processingTime: processingTime
            )

            currentPhase = .completed

            showResultWindow(renderedImage: renderedImage)

        } catch is CancellationError {
            handleCancellation()
            return
        } catch let error as TranslationFlowError {
            handleError(error)
            return
        } catch {
            handleError(.renderingFailure(error.localizedDescription))
            return
        }
    }

    private func handleCancellation() {
        currentPhase = .failed(.cancelled)
        lastError = .cancelled
    }

    private func handleError(_ error: TranslationFlowError) {
        currentPhase = .failed(error)
        lastError = error
        showErrorAlert(error)
    }

    private func showResultWindow(renderedImage: NSImage) {
        guard let cgImage = renderedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        BilingualResultWindowController.shared.showResult(image: cgImage)
    }

    private func showErrorAlert(_ error: TranslationFlowError) {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = String(localized: "translationFlow.error.title")
        alert.informativeText = error.errorDescription ?? String(localized: "translationFlow.error.unknown")
        if let recovery = error.recoverySuggestion {
            alert.informativeText += "\n\n" + recovery
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "common.ok"))
        alert.runModal()
    }
}
