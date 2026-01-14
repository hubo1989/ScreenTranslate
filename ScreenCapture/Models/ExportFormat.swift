import Foundation
import UniformTypeIdentifiers

/// Supported image export formats for screenshots.
enum ExportFormat: String, CaseIterable, Codable, Sendable {
    case png
    case jpeg
    case heic

    /// The Uniform Type Identifier for this format
    var uti: UTType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .heic:
            return .heic
        }
    }

    /// The file extension for this format (without dot)
    var fileExtension: String {
        rawValue
    }

    /// The display name for this format
    var displayName: String {
        switch self {
        case .png:
            return "PNG"
        case .jpeg:
            return "JPEG"
        case .heic:
            return "HEIC"
        }
    }

    /// The MIME type for this format
    var mimeType: String {
        switch self {
        case .png:
            return "image/png"
        case .jpeg:
            return "image/jpeg"
        case .heic:
            return "image/heic"
        }
    }

    /// Estimated bytes per pixel for file size estimation
    /// These are realistic estimates for compressed output files.
    /// PNG: ~1.5 bytes per pixel (lossless, but compressed - desktop screenshots compress well)
    /// JPEG: ~0.3 bytes per pixel at 90% quality
    /// HEIC: ~0.2 bytes per pixel (better compression than JPEG)
    var estimatedBytesPerPixel: Double {
        switch self {
        case .png:
            return 1.5  // Compressed PNG, not raw RGBA
        case .jpeg:
            return 0.3  // Typical JPEG at high quality
        case .heic:
            return 0.2  // HEIC has better compression than JPEG
        }
    }

    /// Whether this format supports quality adjustment
    var supportsQuality: Bool {
        switch self {
        case .png:
            return false
        case .jpeg, .heic:
            return true
        }
    }
}
