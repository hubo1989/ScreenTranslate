import Foundation
import SwiftUI
import AppKit
import Observation

/// ViewModel for the screenshot preview window.
/// Manages screenshot state, annotations, and user actions.
/// Must run on MainActor for UI binding.
@MainActor
@Observable
final class PreviewViewModel {
    // MARK: - Properties

    var screenshot: Screenshot

    @ObservationIgnored
    private(set) var isVisible: Bool = false

    var selectedTool: AnnotationToolType? {
        didSet {
            if oldValue != selectedTool {
                cancelCurrentDrawing()
            }
            if selectedTool != nil && isCropMode {
                isCropMode = false
                cropRect = nil
            }
        }
    }

    var isCropMode: Bool = false {
        didSet {
            if isCropMode && selectedTool != nil {
                selectedTool = nil
            }
            if !isCropMode {
                cropRect = nil
            }
        }
    }

    var cropRect: CGRect?
    var isCropSelecting: Bool = false
    var cropStartPoint: CGPoint?
    var errorMessage: String?
    var isTranslationOverlayVisible: Bool = false

    var isSaving: Bool = false
    var isCopying: Bool = false
    var isCopyingWithTranslations: Bool = false
    var copySuccessMessage: String?

    @ObservationIgnored
    var onDismiss: (() -> Void)?

    @ObservationIgnored
    var onSave: ((URL) -> Void)?

    @ObservationIgnored
    let settings = AppSettings.shared

    @ObservationIgnored
    let imageExporter = ImageExporter.shared

    @ObservationIgnored
    let clipboardService = ClipboardService.shared

    @ObservationIgnored
    let recentCapturesStore: RecentCapturesStore

    @ObservationIgnored
    let ocrService = OCRService.shared

    @ObservationIgnored
    let translationEngine = TranslationEngine.shared

    var ocrResult: OCRResult?
    var translations: [TranslationResult] = []
    var isPerformingOCR: Bool = false
    var isPerformingTranslation: Bool = false
    var isPerformingOCRThenTranslation: Bool = false
    var ocrTranslationError: String?

    // MARK: - Annotation Tools

    @ObservationIgnored
    var rectangleTool = RectangleTool()

    @ObservationIgnored
    var freehandTool = FreehandTool()

    @ObservationIgnored
    var arrowTool = ArrowTool()

    @ObservationIgnored
    var textTool = TextTool()

    var drawingUpdateCounter: Int = 0
    var currentAnnotationInternal: Annotation?
    var isWaitingForTextInputInternal: Bool = false
    var textInputPositionInternal: CGPoint?

    // MARK: - Annotation Selection & Editing

    var selectedAnnotationIndex: Int?
    var isDraggingAnnotation: Bool = false

    @ObservationIgnored
    var dragStartPoint: CGPoint?

    @ObservationIgnored
    var dragOriginalPosition: CGPoint?

    var isDrawing: Bool {
        currentTool?.isActive ?? false
    }

    var currentAnnotation: Annotation? {
        currentAnnotationInternal
    }

    var currentTool: (any AnnotationTool)? {
        guard let selectedTool else { return nil }
        switch selectedTool {
        case .rectangle: return rectangleTool
        case .freehand: return freehandTool
        case .arrow: return arrowTool
        case .text: return textTool
        }
    }

    var isWaitingForTextInput: Bool {
        isWaitingForTextInputInternal
    }

    var textInputContent: String {
        get { textTool.currentText }
        set { textTool.updateText(newValue) }
    }

    var textInputPosition: CGPoint? {
        textInputPositionInternal
    }

    // MARK: - Computed Properties

    var image: CGImage {
        screenshot.image
    }

    var annotations: [Annotation] {
        screenshot.annotations
    }

    var dimensionsText: String {
        screenshot.formattedDimensions
    }

    var fileSizeText: String {
        let format = settings.defaultFormat
        let pixelCount = Double(screenshot.image.width * screenshot.image.height)
        let bytes = Int(pixelCount * format.estimatedBytesPerPixel)

        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    var displayName: String {
        screenshot.sourceDisplay.name
    }

    var format: ExportFormat {
        get { screenshot.format }
        set { screenshot = screenshot.with(format: newValue) }
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    // MARK: - Undo/Redo

    var undoStack: [Screenshot] = []
    var redoStack: [Screenshot] = []

    @ObservationIgnored
    private let maxUndoLevels = 50

    var imageSizeChangeCounter: Int = 0

    // MARK: - Save with Translations

    var isSavingWithTranslations: Bool = false
    var saveSuccessMessage: String?

    // MARK: - Initialization

    init(screenshot: Screenshot, recentCapturesStore: RecentCapturesStore? = nil) {
        self.screenshot = screenshot
        self.recentCapturesStore = recentCapturesStore ?? RecentCapturesStore()
    }

    // MARK: - Public API

    func show() {
        isVisible = true
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        onDismiss?()
    }

    func addAnnotation(_ annotation: Annotation) {
        pushUndoState()
        screenshot = screenshot.adding(annotation)
        redoStack.removeAll()
    }

    func removeAnnotation(at index: Int) {
        guard index >= 0 && index < annotations.count else { return }
        pushUndoState()
        screenshot = screenshot.removingAnnotation(at: index)
        redoStack.removeAll()
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }

        let currentSize = CGSize(width: screenshot.image.width, height: screenshot.image.height)
        let previousSize = CGSize(width: previousState.image.width, height: previousState.image.height)
        let imageSizeChanged = currentSize != previousSize

        redoStack.append(screenshot)
        screenshot = previousState

        if imageSizeChanged {
            imageSizeChangeCounter += 1
        }
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }

        let currentSize = CGSize(width: screenshot.image.width, height: screenshot.image.height)
        let nextSize = CGSize(width: nextState.image.width, height: nextState.image.height)
        let imageSizeChanged = currentSize != nextSize

        undoStack.append(screenshot)
        screenshot = nextState

        if imageSizeChanged {
            imageSizeChangeCounter += 1
        }
    }

    func selectTool(_ tool: AnnotationToolType?) {
        selectedTool = tool
    }

    func dismiss() {
        hide()
    }

    func pushUndoState() {
        undoStack.append(screenshot)

        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
    }

    func clearError() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            errorMessage = nil
        }
    }

    // MARK: - Selected Annotation Properties

    var selectedAnnotationType: AnnotationToolType? {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return nil }

        switch annotations[index] {
        case .rectangle: return .rectangle
        case .freehand: return .freehand
        case .arrow: return .arrow
        case .text: return .text
        }
    }

    var selectedAnnotationColor: CodableColor? {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return nil }

        switch annotations[index] {
        case .rectangle(let rect): return rect.style.color
        case .freehand(let freehand): return freehand.style.color
        case .arrow(let arrow): return arrow.style.color
        case .text(let text): return text.style.color
        }
    }

    var selectedAnnotationStrokeWidth: CGFloat? {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return nil }

        switch annotations[index] {
        case .rectangle(let rect): return rect.style.lineWidth
        case .freehand(let freehand): return freehand.style.lineWidth
        case .arrow(let arrow): return arrow.style.lineWidth
        case .text: return nil
        }
    }

    var selectedAnnotationFontSize: CGFloat? {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return nil }

        if case .text(let text) = annotations[index] {
            return text.style.fontSize
        }
        return nil
    }

    var selectedAnnotationIsFilled: Bool? {
        guard let index = selectedAnnotationIndex,
              index < annotations.count else { return nil }

        if case .rectangle(let rect) = annotations[index] {
            return rect.isFilled
        }
        return nil
    }

    var hasOCRResults: Bool {
        ocrResult?.hasResults ?? false
    }

    var hasTranslationResults: Bool {
        !translations.isEmpty
    }

    var combinedOCRText: String {
        ocrResult?.fullText ?? ""
    }

    var combinedTranslatedText: String {
        translations.map { $0.translatedText }.joined(separator: "\n")
    }
}

// MARK: - Annotation Tool Type

enum AnnotationToolType: String, CaseIterable, Identifiable, Sendable {
    case rectangle
    case freehand
    case arrow
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .freehand: return "Draw"
        case .arrow: return "Arrow"
        case .text: return "Text"
        }
    }

    var keyboardShortcut: Character {
        switch self {
        case .rectangle: return "r"
        case .freehand: return "d"
        case .arrow: return "a"
        case .text: return "t"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: return "rectangle"
        case .freehand: return "pencil.line"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        }
    }
}
