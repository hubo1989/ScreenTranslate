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

    /// Cached permission status - only check once to avoid repeated dialogs
    private var cachedPermissionStatus: Bool?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Returns all available displays for capture.
    /// Uses ScreenCaptureKit's SCShareableContent to enumerate displays.
    /// - Returns: Array of DisplayInfo for all connected displays
    /// - Throws: ScreenTranslateError if enumeration fails or no displays found
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
            throw ScreenTranslateError.captureFailure(underlying: error)
        }

        let scDisplays = content.displays

        guard !scDisplays.isEmpty else {
            throw ScreenTranslateError.captureError(message: "No displays available")
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
    /// - Throws: ScreenTranslateError if no primary display found
    func primaryDisplay() async throws -> DisplayInfo {
        let displays = try await availableDisplays()

        guard let primary = displays.first(where: { $0.isPrimary }) ?? displays.first else {
            throw ScreenTranslateError.captureError(message: "No primary display available")
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
    /// - Throws: ScreenTranslateError.displayNotFound if not found
    func display(withID displayID: CGDirectDisplayID) async throws -> DisplayInfo {
        let displays = try await availableDisplays()

        guard let display = displays.first(where: { $0.id == displayID }) else {
            throw ScreenTranslateError.displayNotFound(displayID)
        }

        return display
    }

    /// Checks if the app has screen recording permission.
    /// Uses SCShareableContent to actually verify permission works (not just cached status).
    /// - Parameter silent: If true, suppresses logging (default: true)
    /// - Returns: True if permission is granted
    func hasPermission(silent: Bool = true) async -> Bool {
        // Quick check first using CGPreflightScreenCaptureAccess
        guard CGPreflightScreenCaptureAccess() else {
            cachedPermissionStatus = false
            if !silent { print("[ScreenDetector] Permission check: denied (CGPreflight)") }
            return false
        }
        // Actually verify by trying to get shareable content
        do {
            _ = try await SCShareableContent.current
            cachedPermissionStatus = true
            if !silent { print("[ScreenDetector] Permission check: granted") }
            return true
        } catch {
            cachedPermissionStatus = false
            if !silent { print("[ScreenDetector] Permission check: denied (SCShareableContent)") }
            return false
        }
    }

    /// Forces a fresh permission check (clears cache)
    func refreshPermissionStatus() async -> Bool {
        cachedPermissionStatus = nil
        return await hasPermission()
    }

    /// Triggers the system permission dialog for screen recording.
    /// Returns true if screen content is currently accessible (does not guarantee user granted permission).
    func requestPermission() async -> Bool {
        do {
            // This triggers the system permission dialog
            _ = try await SCShareableContent.current
            return true
        } catch {
            return false
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
            let deviceDescription = screen.deviceDescription
            let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
            
            guard let screenNumber = deviceDescription[screenNumberKey] as? CGDirectDisplayID else {
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
