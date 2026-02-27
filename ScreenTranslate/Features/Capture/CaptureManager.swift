import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit
import os.signpost

/// Actor responsible for screen capture operations using ScreenCaptureKit.
/// Thread-safe management of capture requests with permission handling.
///
/// ## Memory Usage
/// Peak memory usage is bounded to approximately 2× the captured image size:
/// - 1× for the CGImage buffer from ScreenCaptureKit
/// - 1× for any annotation compositing (temporary, released after save)
///
/// ## Performance Goals
/// - Capture latency: <50ms from trigger to CGImage available
/// - Preview display: <100ms from capture to window visible
/// - Idle CPU: <1% when not capturing
actor CaptureManager {
    // MARK: - Performance Logging

    private static let performanceLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: .pointsOfInterest
    )

    private static let signpostID = OSSignpostID(log: performanceLog)
    // MARK: - Properties

    /// Shared instance for app-wide capture management
    static let shared = CaptureManager()

    /// Screen detector for display enumeration
    private let screenDetector = ScreenDetector.shared

    /// Whether a capture is currently in progress
    private var isCapturing = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Permission Handling

    /// Checks if the app has screen recording permission.
    /// - Returns: True if permission is granted
    var hasPermission: Bool {
        get async {
            await screenDetector.hasPermission()
        }
    }

    /// Requests screen recording permission by triggering the system prompt.
    /// Note: ScreenCaptureKit automatically prompts for permission on first capture attempt.
    /// - Returns: True if permission is now granted
    func requestPermission() async -> Bool {
        // Attempt a capture to trigger the permission prompt
        do {
            let displays = try await screenDetector.availableDisplays()
            guard let display = displays.first else { return false }

            // Create a minimal capture configuration just to trigger the prompt
            guard let scContent = try? await SCShareableContent.current,
                  let scDisplay = scContent.displays.first(where: { $0.displayID == display.id }) else {
                return false
            }

            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = 1
            config.height = 1

            // This will trigger the permission prompt if not already granted
            _ = try? await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            return await hasPermission
        } catch {
            return false
        }
    }

    // MARK: - Full Screen Capture

    /// Captures the full screen of the specified display.
    /// - Parameter display: The display to capture
    /// - Returns: Screenshot containing the captured image and metadata
    /// - Throws: ScreenTranslateError if capture fails
    func captureFullScreen(display: DisplayInfo) async throws -> Screenshot {
        // Prevent concurrent captures
        guard !isCapturing else {
            throw ScreenTranslateError.captureError(message: "Capture already in progress")
        }
        isCapturing = true
        defer { isCapturing = false }

        // Check permission
        guard await hasPermission else {
            throw ScreenTranslateError.permissionDenied
        }

        // Invalidate cache to get fresh display list
        await screenDetector.invalidateCache()

        // Get the SCDisplay for this display
        let scDisplay = try await getSCDisplay(for: display)

        // Configure capture
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = createCaptureConfiguration(for: display)

        // Perform capture with signpost for profiling
        os_signpost(.begin, log: Self.performanceLog, name: "FullScreenCapture", signpostID: Self.signpostID)
        let captureStartTime = CFAbsoluteTimeGetCurrent()

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            os_signpost(.end, log: Self.performanceLog, name: "FullScreenCapture", signpostID: Self.signpostID)
            throw ScreenTranslateError.captureFailure(underlying: error)
        }

        let captureLatency = (CFAbsoluteTimeGetCurrent() - captureStartTime) * 1000
        os_signpost(.end, log: Self.performanceLog, name: "FullScreenCapture", signpostID: Self.signpostID)

        Logger.capture.info("Capture latency: \(String(format: "%.1f", captureLatency))ms")

        // Create screenshot with metadata
        let screenshot = Screenshot(
            image: cgImage,
            captureDate: Date(),
            sourceDisplay: display
        )

        return screenshot
    }

    /// Captures the full screen of the primary display.
    /// - Returns: Screenshot containing the captured image and metadata
    /// - Throws: ScreenTranslateError if capture fails
    func captureFullScreen() async throws -> Screenshot {
        let display = try await screenDetector.primaryDisplay()
        return try await captureFullScreen(display: display)
    }

    // MARK: - Region Capture

    /// Captures a specific region of the specified display.
    /// - Parameters:
    ///   - rect: The region to capture in display coordinates
    ///   - display: The display to capture from
    /// - Returns: Screenshot containing the captured region and metadata
    /// - Throws: ScreenTranslateError if capture fails
    func captureRegion(_ rect: CGRect, from display: DisplayInfo) async throws -> Screenshot {
        // Prevent concurrent captures
        guard !isCapturing else {
            throw ScreenTranslateError.captureError(message: "Capture already in progress")
        }
        isCapturing = true
        defer { isCapturing = false }

        // Check permission
        guard await hasPermission else {
            throw ScreenTranslateError.permissionDenied
        }

        // Invalidate cache to get fresh display list
        await screenDetector.invalidateCache()

        // Get the SCDisplay for this display
        let scDisplay = try await getSCDisplay(for: display)

        // Configure capture
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = createRegionCaptureConfiguration(for: rect, display: display)

        // Perform capture with signpost for profiling
        os_signpost(.begin, log: Self.performanceLog, name: "RegionCapture", signpostID: Self.signpostID)
        let captureStartTime = CFAbsoluteTimeGetCurrent()

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            os_signpost(.end, log: Self.performanceLog, name: "RegionCapture", signpostID: Self.signpostID)
            throw ScreenTranslateError.captureFailure(underlying: error)
        }

        let captureLatency = (CFAbsoluteTimeGetCurrent() - captureStartTime) * 1000
        os_signpost(.end, log: Self.performanceLog, name: "RegionCapture", signpostID: Self.signpostID)

        Logger.capture.info("Region capture latency: \(String(format: "%.1f", captureLatency))ms")

        // Create screenshot with metadata
        return Screenshot(
            image: cgImage,
            captureDate: Date(),
            sourceDisplay: display
        )
    }

    // MARK: - Display Enumeration

    /// Returns all available displays for capture.
    /// - Returns: Array of DisplayInfo for all connected displays
    /// - Throws: ScreenTranslateError if enumeration fails
    func availableDisplays() async throws -> [DisplayInfo] {
        try await screenDetector.availableDisplays()
    }

    /// Returns the primary display.
    /// - Returns: DisplayInfo for the main display
    /// - Throws: ScreenTranslateError if no primary display found
    func primaryDisplay() async throws -> DisplayInfo {
        try await screenDetector.primaryDisplay()
    }

    // MARK: - Private Methods

    /// Creates a capture configuration optimized for the given display.
    /// - Parameter display: The display to configure for
    /// - Returns: SCStreamConfiguration with appropriate settings
    private func createCaptureConfiguration(for display: DisplayInfo) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        // Set dimensions to match display's pixel resolution
        config.width = Int(display.frame.width * display.scaleFactor)
        config.height = Int(display.frame.height * display.scaleFactor)

        // High quality settings for screenshots
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // Single frame
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false // Typically hide cursor in screenshots

        // Color settings for accurate reproduction
        config.colorSpaceName = CGColorSpace.sRGB

        return config
    }

    /// Retrieves the SCDisplay corresponding to the given DisplayInfo.
    /// - Parameter display: The display to find
    /// - Returns: The matching SCDisplay
    /// - Throws: ScreenTranslateError if display not found or content retrieval fails
    private func getSCDisplay(for display: DisplayInfo) async throws -> SCDisplay {
        let scContent: SCShareableContent
        do {
            scContent = try await SCShareableContent.current
        } catch {
            throw ScreenTranslateError.captureFailure(underlying: error)
        }

        guard let scDisplay = scContent.displays.first(where: { $0.displayID == display.id }) else {
            throw ScreenTranslateError.displayDisconnected(displayName: display.name)
        }
        return scDisplay
    }

    /// Creates a capture configuration for a specific region.
    /// - Parameters:
    ///   - rect: The region to capture in points
    ///   - display: The display to capture from
    /// - Returns: Configured SCStreamConfiguration
    private func createRegionCaptureConfiguration(for rect: CGRect, display: DisplayInfo) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        
        // sourceRect is in POINTS (same coordinate system as display.frame)
        let clampedX = min(max(rect.origin.x, 0), display.frame.width - 1)
        let clampedY = min(max(rect.origin.y, 0), display.frame.height - 1)
        let clampedWidth = min(rect.width, display.frame.width - clampedX)
        let clampedHeight = min(rect.height, display.frame.height - clampedY)

        let sourceRect = CGRect(
            x: clampedX,
            y: clampedY,
            width: clampedWidth,
            height: clampedHeight
        )

        config.sourceRect = sourceRect
        
        // Output size should be in PIXELS for crisp capture
        let outputWidth = Int(clampedWidth * display.scaleFactor)
        let outputHeight = Int(clampedHeight * display.scaleFactor)
        config.width = outputWidth
        config.height = outputHeight
        
        // High quality settings
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.colorSpaceName = CGColorSpace.sRGB

        // Debug logging
        Logger.capture.debug("=== CAPTURE MANAGER DEBUG ===")
        Logger.capture.debug("[CAP-1] Input rect (points): \(String(describing: rect))")
        Logger.capture.debug("[CAP-2] display.frame (points): \(String(describing: display.frame))")
        Logger.capture.debug("[CAP-3] display.scaleFactor: \(display.scaleFactor)")
        Logger.capture.debug("[CAP-4] sourceRect (points, clamped): \(String(describing: sourceRect))")
        Logger.capture.debug("[CAP-5] outputSize (pixels): \(outputWidth)x\(outputHeight)")
        Logger.capture.debug("=== END CAPTURE MANAGER DEBUG ===")

        return config
    }
}
