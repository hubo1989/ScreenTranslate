import Foundation

/// OCR engine types supported by the application
enum OCREngineType: String, CaseIterable, Sendable, Codable {
    /// macOS native Vision framework (local, default)
    case vision = "vision"

    /// PaddleOCR (optional, external)
    case paddleOCR = "paddleocr"

    /// Localized display name
    var localizedName: String {
        switch self {
        case .vision:
            return NSLocalizedString("ocr.engine.vision", comment: "Vision (Local)")
        case .paddleOCR:
            return NSLocalizedString("ocr.engine.paddleocr", comment: "PaddleOCR")
        }
    }

    /// Description of the engine
    var description: String {
        switch self {
        case .vision:
            return NSLocalizedString(
                "ocr.engine.vision.description",
                comment: "Built-in macOS engine, no setup required"
            )
        case .paddleOCR:
            return NSLocalizedString(
                "ocr.engine.paddleocr.description",
                comment: "External OCR engine for enhanced accuracy"
            )
        }
    }

    /// Whether this engine is available (local engines are always available)
    var isAvailable: Bool {
        switch self {
        case .vision:
            return true
        case .paddleOCR:
            // PaddleOCR requires external setup
            return false
        }
    }
}
