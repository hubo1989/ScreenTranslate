import CoreGraphics
import Foundation

struct ImageTranslationPipelineConfig: Sendable, Equatable {
    let targetLanguage: String
    let sourceLanguage: String?
    let preferredEngine: TranslationEngineType
    let scene: TranslationScene?
    let mode: EngineSelectionMode
    let fallbackEnabled: Bool
    let parallelEngines: [TranslationEngineType]
    let sceneBindings: [TranslationScene: SceneEngineBinding]

    @MainActor
    static func fromAppSettings(scene: TranslationScene? = nil) -> ImageTranslationPipelineConfig {
        let settings = AppSettings.shared
        return ImageTranslationPipelineConfig(
            targetLanguage: settings.translationTargetLanguage?.rawValue ?? "zh-Hans",
            sourceLanguage: settings.translationSourceLanguage == .auto
                ? nil
                : settings.translationSourceLanguage.rawValue,
            preferredEngine: settings.translationEngine,
            scene: scene,
            mode: settings.engineSelectionMode,
            fallbackEnabled: settings.translationFallbackEnabled,
            parallelEngines: settings.parallelEngines,
            sceneBindings: settings.sceneBindings
        )
    }
}

struct ImageTranslationPipelineOutput: Sendable, Equatable {
    let originalImage: CGImage
    let renderedImage: CGImage
    let analysisResult: ScreenAnalysisResult
    let filteredAnalysisResult: ScreenAnalysisResult
    let segments: [BilingualSegment]
    let processingTime: TimeInterval

    var flowResult: TranslationFlowResult {
        TranslationFlowResult(
            originalImage: originalImage,
            renderedImage: renderedImage,
            segments: segments,
            processingTime: processingTime
        )
    }
}

@available(macOS 13.0, *)
final class ImageTranslationPipeline: Sendable {
    typealias Analyzer = @Sendable (CGImage) async throws -> ScreenAnalysisResult
    typealias OCRFallback = @Sendable (CGImage) async throws -> OCRResult
    typealias Renderer = @Sendable (CGImage, [BilingualSegment], OverlayTheme) -> CGImage?

    private let analyzer: Analyzer
    private let ocrFallback: OCRFallback
    private let translationService: any TranslationServicing
    private let renderer: Renderer
    private let recorder: PerformanceRecorder

    init(
        analyzer: @escaping Analyzer = { image in
            try await ScreenCoderEngine.shared.analyze(image: image)
        },
        ocrFallback: @escaping OCRFallback = { image in
            try await OCRService.shared.recognize(image)
        },
        translationService: any TranslationServicing = TranslationService.shared,
        renderer: @escaping Renderer = { image, segments, theme in
            OverlayRenderer().render(image: image, segments: segments, theme: theme)
        },
        recorder: PerformanceRecorder = .shared
    ) {
        self.analyzer = analyzer
        self.ocrFallback = ocrFallback
        self.translationService = translationService
        self.renderer = renderer
        self.recorder = recorder
    }

    func run(
        image: CGImage,
        config: ImageTranslationPipelineConfig,
        theme: OverlayTheme,
        context: PipelineContext = PipelineContext()
    ) async throws -> ImageTranslationPipelineOutput {
        let analysisResult = try await analyze(image: image, context: context)
        let filteredAnalysisResult = analysisResult.filteredForTranslation()
        guard !filteredAnalysisResult.segments.isEmpty else {
            throw PipelineError.noTextFound
        }

        let bilingualSegments = try await translate(
            analysisResult: filteredAnalysisResult,
            config: config,
            context: context
        )

        let renderedImage = try await render(
            image: image,
            segments: bilingualSegments,
            theme: theme,
            context: context
        )

        return ImageTranslationPipelineOutput(
            originalImage: image,
            renderedImage: renderedImage,
            analysisResult: analysisResult,
            filteredAnalysisResult: filteredAnalysisResult,
            segments: bilingualSegments,
            processingTime: context.elapsed
        )
    }

    func analyze(image: CGImage, context: PipelineContext) async throws -> ScreenAnalysisResult {
        do {
            return try await recorder.measure(stage: .analysis, operationID: context.operationID) {
                try Task.checkCancellation()
                let initialAnalysis = try await analyzer(image)
                return try await Self.recoverAnalysisResultIfNeeded(initialAnalysis) {
                    try await ocrFallback(image)
                }
            }
        } catch {
            throw PipelineError(stage: .analysis, error: error)
        }
    }

    func translate(
        analysisResult: ScreenAnalysisResult,
        config: ImageTranslationPipelineConfig,
        context: PipelineContext
    ) async throws -> [BilingualSegment] {
        do {
            return try await recorder.measure(stage: .translation, operationID: context.operationID) {
                try Task.checkCancellation()
                let texts = analysisResult.segments.map(\.text)
                let translatedSegments = try await translationService.translate(
                    segments: texts,
                    to: config.targetLanguage,
                    preferredEngine: config.preferredEngine,
                    from: config.sourceLanguage,
                    scene: config.scene,
                    mode: config.mode,
                    fallbackEnabled: config.fallbackEnabled,
                    parallelEngines: config.parallelEngines,
                    sceneBindings: config.sceneBindings
                )

                return zip(analysisResult.segments, translatedSegments).map { original, translated in
                    BilingualSegment(
                        segment: original,
                        translatedText: translated.translated,
                        sourceLanguage: translated.sourceLanguage,
                        targetLanguage: translated.targetLanguage
                    )
                }
            }
        } catch {
            throw PipelineError(stage: .translation, error: error)
        }
    }

    func render(
        image: CGImage,
        segments: [BilingualSegment],
        theme: OverlayTheme,
        context: PipelineContext
    ) async throws -> CGImage {
        do {
            return try await recorder.measure(stage: .render, operationID: context.operationID) {
                try Task.checkCancellation()
                guard let renderedImage = renderer(image, segments, theme) else {
                    throw PipelineError.renderFailed("Failed to render overlay")
                }
                return renderedImage
            }
        } catch {
            throw PipelineError(stage: .render, error: error)
        }
    }

    static func recoverAnalysisResultIfNeeded(
        _ analysisResult: ScreenAnalysisResult,
        ocrFallback: @Sendable () async throws -> OCRResult
    ) async throws -> ScreenAnalysisResult {
        guard analysisResult.containsOnlyPromptLeakage else {
            return analysisResult
        }

        let fallbackResult = try await ocrFallback()
        let recoveredResult = ScreenAnalysisResult(ocrResult: fallbackResult)
        return recoveredResult.segments.isEmpty ? analysisResult : recoveredResult
    }
}
