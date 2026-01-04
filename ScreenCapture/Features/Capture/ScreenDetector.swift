import Foundation
@preconcurrency import ScreenCaptureKit
import AppKit

/// Service responsible for enumerating connected displays using ScreenCaptureKit.
/// Thread-safe actor that provides display discovery and matching with NSScreen.
actor ScreenDetector {
    // MARK: - Types

    /// Error types specific to screen detection
    enum Error: Swift.Error, LocalizedError {
        case noDisplaysFound
        case contentUnavailable

        var errorDescription: String? {
            switch self {
            case .noDisplaysFound:
                return "No displays found"
            case .contentUnavailable:
                return "Screen content is not available"
            }
        }
    }

    // MARK: - Properties

    /// Shared instance for app-wide display detection
    static let shared = ScreenDetector()

    /// Cached displays from last enumeration
    private var cachedDisplays: [DisplayInfo] = []

    /// Last time displays were enumerated
    private var lastEnumerationTime: Date?

    /// Cache validity duration (5 seconds)
    private let cacheValidityDuration: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Returns all available displays for capture.
    /// Uses ScreenCaptureKit's SCShareableContent to enumerate displays.
    /// - Returns: Array of DisplayInfo for all connected displays
    /// - Throws: ScreenCaptureError if enumeration fails or no displays found
    func availableDisplays() async throws -> [DisplayInfo] {
        // Check cache validity
        if let lastTime = lastEnumerationTime,
           Date().timeIntervalSince(lastTime) < cacheValidityDuration,
           !cachedDisplays.isEmpty {
            return cachedDisplays
        }

        // Enumerate displays using ScreenCaptureKit
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw ScreenCaptureError.captureFailure(underlying: error)
        }

        let scDisplays = content.displays

        guard !scDisplays.isEmpty else {
            throw ScreenCaptureError.captureError(message: "No displays available")
        }

        // Map SCDisplay to DisplayInfo with NSScreen matching
        let displays = await MainActor.run {
            scDisplays.map { scDisplay -> DisplayInfo in
                let matchingScreen = Self.findMatchingScreen(for: scDisplay)
                return DisplayInfo(scDisplay: scDisplay, screen: matchingScreen)
            }
        }

        // Update cache
        cachedDisplays = displays
        lastEnumerationTime = Date()

        return displays
    }

    /// Returns the primary (main) display.
    /// - Returns: DisplayInfo for the main display
    /// - Throws: ScreenCaptureError if no primary display found
    func primaryDisplay() async throws -> DisplayInfo {
        let displays = try await availableDisplays()

        guard let primary = displays.first(where: { $0.isPrimary }) ?? displays.first else {
            throw ScreenCaptureError.captureError(message: "No primary display available")
        }

        return primary
    }

    /// Returns the display at the given point (for cursor-based selection).
    /// - Parameter point: Point in global screen coordinates
    /// - Returns: DisplayInfo for the display containing the point, or nil
    func display(containing point: CGPoint) async throws -> DisplayInfo? {
        let displays = try await availableDisplays()
        return displays.first { $0.frame.contains(point) }
    }

    /// Returns the display with the specified ID.
    /// - Parameter displayID: The CGDirectDisplayID to find
    /// - Returns: DisplayInfo for the specified display
    /// - Throws: ScreenCaptureError.displayNotFound if not found
    func display(withID displayID: CGDirectDisplayID) async throws -> DisplayInfo {
        let displays = try await availableDisplays()

        guard let display = displays.first(where: { $0.id == displayID }) else {
            throw ScreenCaptureError.displayNotFound(displayID)
        }

        return display
    }

    /// Checks if the app has screen recording permission.
    /// - Returns: True if permission is granted
    var hasPermission: Bool {
        get async {
            do {
                // Attempt to get shareable content - this will fail if no permission
                _ = try await SCShareableContent.current
                return true
            } catch {
                return false
            }
        }
    }

    /// Clears the display cache, forcing a fresh enumeration on next call.
    func invalidateCache() {
        cachedDisplays = []
        lastEnumerationTime = nil
    }

    // MARK: - Private Methods

    /// Finds the NSScreen that matches a given SCDisplay.
    /// - Parameter scDisplay: The ScreenCaptureKit display
    /// - Returns: The matching NSScreen, or nil if not found
    @MainActor
    private static func findMatchingScreen(for scDisplay: SCDisplay) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return screenNumber == scDisplay.displayID
        }
    }
}

// MARK: - SCShareableContent Extension

extension SCShareableContent {
    /// Gets the current shareable content (displays, windows, apps).
    /// Async wrapper around the completion handler API.
    static var current: SCShareableContent {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                SCShareableContent.getWithCompletionHandler { content, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let content = content {
                        continuation.resume(returning: content)
                    } else {
                        continuation.resume(throwing: ScreenDetector.Error.contentUnavailable)
                    }
                }
            }
        }
    }
}
