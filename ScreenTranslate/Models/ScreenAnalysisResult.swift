import CoreGraphics
import Foundation

// MARK: - TextSegment

/// A single text segment extracted by VLM analysis.
/// Contains the recognized text, its normalized position, and confidence score.
struct TextSegment: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier for this segment
    let id: UUID

    /// The recognized text content
    let text: String

    /// Bounding box of the text in the image (normalized coordinates 0-1)
    /// Origin is top-left, coordinates represent (x, y, width, height)
    let boundingBox: CGRect

    /// Confidence score from VLM (0.0 to 1.0)
    let confidence: Float

    /// Initialize with all properties
    init(id: UUID = UUID(), text: String, boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }

    /// Whether this segment has high confidence (> 0.7)
    var isHighConfidence: Bool {
        confidence > 0.7
    }
}

// MARK: - TextSegment Bounding Box Utilities

extension TextSegment {
    /// Returns the bounding box in pixel coordinates
    /// - Parameter imageSize: The image size in pixels
    /// - Returns: Bounding box in pixel coordinates
    func pixelBoundingBox(in imageSize: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.minX * imageSize.width,
            y: boundingBox.minY * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
    }

    /// Returns the center point in pixel coordinates
    /// - Parameter imageSize: The image size in pixels
    /// - Returns: Center point in pixel coordinates
    func centerPoint(in imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: boundingBox.midX * imageSize.width,
            y: boundingBox.midY * imageSize.height
        )
    }
}

// MARK: - ScreenAnalysisResult

/// The result of VLM-based screen analysis.
/// Contains all extracted text segments with their positions.
struct ScreenAnalysisResult: Codable, Sendable, Equatable {
    /// All text segments found in the image
    let segments: [TextSegment]

    /// The source image dimensions (width x height in pixels)
    let imageSize: CGSize

    /// Initialize with segments and image size
    init(segments: [TextSegment] = [], imageSize: CGSize) {
        self.segments = segments
        self.imageSize = imageSize
    }

    /// Total number of text segments
    var count: Int {
        segments.count
    }

    /// Whether any text was found
    var hasResults: Bool {
        !segments.isEmpty
    }

    /// All recognized text concatenated with newlines, sorted by vertical position
    var fullText: String {
        segments
            .sorted { $0.boundingBox.minY < $1.boundingBox.minY }
            .map(\.text)
            .joined(separator: "\n")
    }

    /// Filter segments by minimum confidence level
    func filter(minimumConfidence: Float) -> ScreenAnalysisResult {
        let filtered = segments.filter { $0.confidence >= minimumConfidence }
        return ScreenAnalysisResult(segments: filtered, imageSize: imageSize)
    }

    /// Get segments within a specific region
    func segments(in rect: CGRect) -> [TextSegment] {
        segments.filter { $0.boundingBox.intersects(rect) }
    }
}

// MARK: - Empty Result

extension ScreenAnalysisResult {
    /// Creates an empty analysis result for the given image size
    static func empty(imageSize: CGSize) -> ScreenAnalysisResult {
        ScreenAnalysisResult(segments: [], imageSize: imageSize)
    }
}
