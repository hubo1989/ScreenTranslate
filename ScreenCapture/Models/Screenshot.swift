import Foundation
import CoreGraphics
import AppKit

/// Represents a captured screen image with metadata.
struct Screenshot: Identifiable, Sendable {
    /// Unique identifier for this screenshot
    let id: UUID

    /// Raw captured image data
    let image: CGImage

    /// When the capture occurred
    let captureDate: Date

    /// Display from which this was captured
    let sourceDisplay: DisplayInfo

    /// Width x Height in pixels (derived from image)
    var dimensions: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// Drawing overlays (initially empty)
    var annotations: [Annotation]

    /// Saved file location (nil until saved)
    var filePath: URL?

    /// Export format (PNG or JPEG)
    var format: ExportFormat

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        image: CGImage,
        captureDate: Date = Date(),
        sourceDisplay: DisplayInfo,
        annotations: [Annotation] = [],
        filePath: URL? = nil,
        format: ExportFormat = .png
    ) {
        self.id = id
        self.image = image
        self.captureDate = captureDate
        self.sourceDisplay = sourceDisplay
        self.annotations = annotations
        self.filePath = filePath
        self.format = format
    }

    // MARK: - Computed Properties

    /// Estimated file size in bytes based on format and dimensions
    var estimatedFileSize: Int {
        let pixelCount = Double(image.width * image.height)
        return Int(pixelCount * format.estimatedBytesPerPixel)
    }

    /// Formatted estimated file size (e.g., "1.2 MB")
    var formattedFileSize: String {
        let bytes = estimatedFileSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    /// Aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard image.height > 0 else { return 1.0 }
        return CGFloat(image.width) / CGFloat(image.height)
    }

    /// Whether this screenshot has been saved to disk
    var isSaved: Bool {
        filePath != nil
    }

    /// Whether this screenshot has any annotations
    var hasAnnotations: Bool {
        !annotations.isEmpty
    }

    /// Formatted dimensions string (e.g., "1920 x 1080")
    var formattedDimensions: String {
        "\(image.width) x \(image.height)"
    }
}

// MARK: - Thumbnail Generation

extension Screenshot {
    /// Generates a scaled-down preview image (max 256px on longest edge)
    func generateThumbnail(maxSize: CGFloat = 256) -> CGImage? {
        let scale = min(maxSize / CGFloat(image.width), maxSize / CGFloat(image.height), 1.0)
        let newWidth = Int(CGFloat(image.width) * scale)
        let newHeight = Int(CGFloat(image.height) * scale)

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: newWidth,
                  height: newHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage()
    }
}

// MARK: - State Transitions

extension Screenshot {
    /// Creates a copy with the file path set (after saving)
    func saved(to url: URL) -> Screenshot {
        var copy = self
        copy.filePath = url
        return copy
    }

    /// Creates a copy with an added annotation
    func adding(_ annotation: Annotation) -> Screenshot {
        var copy = self
        copy.annotations.append(annotation)
        return copy
    }

    /// Creates a copy with the annotation at the given index removed
    func removingAnnotation(at index: Int) -> Screenshot {
        var copy = self
        guard index >= 0 && index < copy.annotations.count else { return copy }
        copy.annotations.remove(at: index)
        return copy
    }

    /// Creates a copy with the annotation at the given index replaced
    func replacingAnnotation(at index: Int, with annotation: Annotation) -> Screenshot {
        var copy = self
        guard index >= 0 && index < copy.annotations.count else { return copy }
        copy.annotations[index] = annotation
        return copy
    }

    /// Creates a copy with the specified format
    func with(format: ExportFormat) -> Screenshot {
        var copy = self
        copy.format = format
        return copy
    }
}
