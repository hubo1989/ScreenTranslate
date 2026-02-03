import CoreGraphics
import AppKit
import ImageIO
import UniformTypeIdentifiers

extension CGImage {
    /// Creates a scaled copy of this image
    /// - Parameter scale: Scale factor (0.0-1.0 to shrink, >1.0 to enlarge)
    /// - Returns: A new scaled CGImage, or nil if creation fails
    func scaled(by scale: CGFloat) -> CGImage? {
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)
        return resized(to: CGSize(width: newWidth, height: newHeight))
    }

    /// Creates a resized copy of this image
    /// - Parameter size: The target size in pixels
    /// - Returns: A new resized CGImage, or nil if creation fails
    func resized(to size: CGSize) -> CGImage? {
        let newWidth = Int(size.width)
        let newHeight = Int(size.height)

        guard newWidth > 0 && newHeight > 0 else { return nil }

        guard let colorSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
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
        context.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage()
    }

    /// Crops this image to the specified rectangle
    /// - Parameter rect: The crop rectangle in image coordinates
    /// - Returns: A new cropped CGImage, or nil if cropping fails
    func cropped(to rect: CGRect) -> CGImage? {
        cropping(to: rect)
    }

    /// Returns the size of this image in pixels
    var size: CGSize {
        CGSize(width: width, height: height)
    }

    /// Returns the aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.0 }
        return CGFloat(width) / CGFloat(height)
    }

    /// Encodes this image to PNG data
    var pngData: Data? {
        encode(as: ExportFormat.png)
    }

    /// Encodes this image to JPEG data with the specified quality
    /// - Parameter quality: Compression quality (0.0-1.0)
    func jpegData(quality: CGFloat = 0.9) -> Data? {
        encode(as: ExportFormat.jpeg, quality: quality)
    }

    /// Encodes this image to the specified format
    /// - Parameters:
    ///   - format: The target export format
    ///   - quality: Compression quality for JPEG (0.0-1.0)
    /// - Returns: Encoded data, or nil if encoding fails
    func encode(as format: ExportFormat, quality: CGFloat = 0.9) -> Data? {
        encode(as: format.uti, quality: quality)
    }

    /// Encodes this image using the specified UTType
    /// - Parameters:
    ///   - type: The uniform type identifier
    ///   - quality: Compression quality for lossy formats (0.0-1.0)
    /// - Returns: Encoded data, or nil if encoding fails
    private func encode(as type: UTType, quality: CGFloat = 0.9) -> Data? {
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            type.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        var options: [CFString: Any] = [:]
        if type == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        CGImageDestinationAddImage(destination, self, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    /// Writes this image to a file at the specified URL
    /// - Parameters:
    ///   - url: The destination file URL
    ///   - format: The export format
    ///   - quality: Compression quality for JPEG (0.0-1.0)
    /// - Throws: ScreenTranslateError if writing fails
    func write(to url: URL, format: ExportFormat, quality: CGFloat = 0.9) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.uti.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenTranslateError.exportEncodingFailed(format: format)
        }

        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        CGImageDestinationAddImage(destination, self, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenTranslateError.exportEncodingFailed(format: format)
        }
    }

    /// Creates an NSImage from this CGImage
    var nsImage: NSImage {
        NSImage(cgImage: self)
    }

    /// Estimates the file size in bytes for the given format
    /// - Parameter format: The export format
    /// - Returns: Estimated size in bytes
    func estimatedFileSize(for format: ExportFormat) -> Int {
        let pixelCount = Double(width * height)
        return Int(pixelCount * format.estimatedBytesPerPixel)
    }
}
