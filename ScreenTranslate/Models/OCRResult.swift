import Foundation
import CoreGraphics
import Vision

/// The result of an OCR operation on an image.
/// Contains all recognized text with their positions and confidence scores.
struct OCRResult: Sendable {
    /// All text observations found in the image
    let observations: [OCRText]

    /// The source image dimensions (width x height in pixels)
    let imageSize: CGSize

    /// When OCR was performed
    let timestamp: Date

    /// Total number of text observations
    var count: Int {
        observations.count
    }

    /// All recognized text concatenated with newlines
    var fullText: String {
        observations
            .sorted { $0.boundingBox.minY < $1.boundingBox.minY }
            .map(\.text)
            .joined(separator: "\n")
    }

    /// Whether any text was found
    var hasResults: Bool {
        !observations.isEmpty
    }

    /// Initialize with observations and image size
    init(observations: [OCRText] = [], imageSize: CGSize, timestamp: Date = Date()) {
        self.observations = observations
        self.imageSize = imageSize
        self.timestamp = timestamp
    }

    /// Filter observations by minimum confidence level
    func filter(minimumConfidence: Float) -> OCRResult {
        let filtered = observations.filter { $0.confidence >= minimumConfidence }
        return OCRResult(observations: filtered, imageSize: imageSize, timestamp: timestamp)
    }

    /// Get observations within a specific region
    func observations(in rect: CGRect) -> [OCRText] {
        observations.filter { $0.boundingBox.intersects(rect) }
    }
}

// MARK: - Empty Result

extension OCRResult {
    /// Creates an empty OCR result for the given image size
    static func empty(imageSize: CGSize) -> OCRResult {
        OCRResult(observations: [], imageSize: imageSize)
    }
}

/// A single text observation from OCR.
/// Contains the recognized text, its position, and confidence score.
struct OCRText: Identifiable, Sendable {
    /// Unique identifier for this observation
    let id: UUID

    /// The recognized text content
    let text: String

    /// Bounding box of the text in the image (normalized 0-1)
    let boundingBox: CGRect

    /// Confidence score (0.0 to 1.0)
    let confidence: Float

    /// Initialize with text, bounding box, and confidence
    init(id: UUID = UUID(), text: String, boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }

    /// Whether this observation has high confidence (> 0.5)
    var isHighConfidence: Bool {
        confidence > 0.5
    }

    /// Whether this observation has very high confidence (> 0.8)
    var isVeryHighConfidence: Bool {
        confidence > 0.8
    }
}

// MARK: - Vision Framework Conversion

extension OCRText {
    /// Creates an OCRText from a VNRecognizedTextObservation
    /// - Parameter observation: The Vision framework text observation
    /// - Parameter imageSize: The source image size for coordinate conversion
    /// - Returns: An OCRText if text extraction succeeds, nil otherwise
    static func from(
        _ observation: VNRecognizedTextObservation,
        imageSize: CGSize
    ) -> OCRText? {
        guard let topCandidate = observation.topCandidates(1).first else {
            return nil
        }

        // Vision returns normalized bounding box (bottom-left origin)
        // Convert to standard coordinate system (top-left origin)
        let visionBox = observation.boundingBox

        // Convert from bottom-left origin to top-left origin
        let normalizedY = 1.0 - visionBox.maxY
        let normalizedHeight = visionBox.height

        let boundingBox = CGRect(
            x: visionBox.minX,
            y: normalizedY,
            width: visionBox.width,
            height: normalizedHeight
        )

        return OCRText(
            text: topCandidate.string,
            boundingBox: boundingBox,
            confidence: topCandidate.confidence
        )
    }
}

// MARK: - Bounding Box Utilities

extension OCRText {
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

    /// Returns the center point of the text in pixel coordinates
    /// - Parameter imageSize: The image size in pixels
    /// - Returns: Center point in pixel coordinates
    func centerPoint(in imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: boundingBox.midX * imageSize.width,
            y: boundingBox.midY * imageSize.height
        )
    }
}

// MARK: - Equatable Conformance

extension OCRText: Equatable {
    static func == (lhs: OCRText, rhs: OCRText) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.boundingBox == rhs.boundingBox &&
        lhs.confidence == rhs.confidence
    }
}
