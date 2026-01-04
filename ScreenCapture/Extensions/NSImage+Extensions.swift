import AppKit
import CoreGraphics

extension NSImage {
    /// Creates an NSImage from a CGImage
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Returns the CGImage representation of this NSImage
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Generates a thumbnail with the specified maximum dimension
    /// - Parameter maxSize: Maximum width or height in points
    /// - Returns: A scaled NSImage, or nil if generation fails
    func thumbnail(maxSize: CGFloat) -> NSImage? {
        let currentSize = size
        guard currentSize.width > 0 && currentSize.height > 0 else { return nil }

        let scale = min(maxSize / currentSize.width, maxSize / currentSize.height, 1.0)
        let newSize = NSSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: currentSize),
            operation: .copy,
            fraction: 1.0
        )

        thumbnail.unlockFocus()
        return thumbnail
    }

    /// Generates thumbnail data as JPEG with specified quality
    /// - Parameters:
    ///   - maxSize: Maximum width or height in points
    ///   - quality: JPEG compression quality (0.0-1.0)
    /// - Returns: JPEG data, or nil if generation fails
    func thumbnailData(maxSize: CGFloat = 128, quality: CGFloat = 0.7) -> Data? {
        guard let thumbnail = thumbnail(maxSize: maxSize),
              let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }

    /// Returns the size in pixels (accounting for backing scale)
    var pixelSize: NSSize {
        guard let cgImage = cgImage else { return size }
        return NSSize(width: cgImage.width, height: cgImage.height)
    }

    /// Creates a copy of the image resized to fit within the specified bounds
    /// - Parameter bounds: Maximum size in points
    /// - Returns: A new resized NSImage
    func resized(toFit bounds: NSSize) -> NSImage {
        let currentSize = size
        guard currentSize.width > 0 && currentSize.height > 0 else { return self }

        let widthRatio = bounds.width / currentSize.width
        let heightRatio = bounds.height / currentSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        let newSize = NSSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )

        let resized = NSImage(size: newSize)
        resized.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: currentSize),
            operation: .copy,
            fraction: 1.0
        )

        resized.unlockFocus()
        return resized
    }

    /// Creates a PNG data representation of the image
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Creates a JPEG data representation of the image
    /// - Parameter quality: Compression quality (0.0-1.0)
    func jpegData(quality: CGFloat = 0.9) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }
}
