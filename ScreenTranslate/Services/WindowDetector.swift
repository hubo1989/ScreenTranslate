import Foundation
import CoreGraphics
import AppKit

/// Represents a window detected by CGWindowListCopyWindowInfo
struct WindowInfo: Identifiable, Hashable, Sendable {
    /// Unique identifier for Identifiable conformance (uses windowID as UInt)
    var id: UInt { UInt(windowID) }

    /// System window identifier (CGWindowID)
    let windowID: CGWindowID

    /// Window position and size in global screen coordinates
    let frame: CGRect

    /// Name of the application that owns this window
    let ownerName: String

    /// Title of the window (may be empty for some windows)
    let windowName: String

    /// Window layer level (0 = normal windows, >0 = floating windows, <0 = desktop elements)
    let windowLayer: Int

    /// Whether this window is the main/key window of its application
    let isOnScreen: Bool

    /// Alpha value of the window (0.0 - 1.0)
    let alpha: Double

    // MARK: - Computed Properties

    /// User-visible display name (uses window name if available, otherwise owner name)
    var displayName: String {
        if !windowName.isEmpty {
            return windowName
        }
        return ownerName
    }

    /// Whether this is a normal application window (layer 0)
    var isNormalWindow: Bool {
        windowLayer == 0
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.windowID == rhs.windowID
    }
}

// MARK: - Window Detection Service

/// Service responsible for detecting windows under the cursor using CGWindowListCopyWindowInfo.
/// Provides synchronous window enumeration for high-frequency mouse tracking scenarios.
actor WindowDetector {
    // MARK: - Types

    /// Error types specific to window detection
    enum Error: Swift.Error, LocalizedError {
        case windowListUnavailable
        case invalidWindowInfo

        var errorDescription: String? {
            switch self {
            case .windowListUnavailable:
                return "Unable to retrieve window list"
            case .invalidWindowInfo:
                return "Invalid window information received"
            }
        }
    }

    // MARK: - Properties

    /// Shared instance for app-wide window detection
    static let shared = WindowDetector()

    /// Cached window list from last enumeration
    private var cachedWindows: [WindowInfo] = []

    /// Last time windows were enumerated
    private var lastEnumerationTime: Date?

    /// Cache validity duration (100ms for high-frequency updates)
    private let cacheValidityDuration: TimeInterval = 0.1

    /// Bundle identifier of the current app (used to filter own windows)
    private let ownBundleIdentifier: String

    // MARK: - Initialization

    private init() {
        self.ownBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.screentranslate"
    }

    // MARK: - Public API

    /// Returns all visible windows sorted by Z-order (front to back).
    /// Filters out system windows (Dock, Menu Bar) and own app's overlay windows.
    /// - Returns: Array of WindowInfo for all visible windows
    func visibleWindows() -> [WindowInfo] {
        // Check cache validity
        if let lastTime = lastEnumerationTime,
           Date().timeIntervalSince(lastTime) < cacheValidityDuration,
           !cachedWindows.isEmpty {
            return cachedWindows
        }

        // Get window list from Core Graphics
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        // Parse and filter windows
        let windows = parseWindowList(windowList)

        // Update cache
        cachedWindows = windows
        lastEnumerationTime = Date()

        return windows
    }

    /// Returns the topmost visible window at the given point.
    /// Searches through visible windows in Z-order and returns the first match.
    /// - Parameter point: Point in global screen coordinates (Quartz coordinate system)
    /// - Returns: WindowInfo for the window at the point, or nil if none found
    func windowUnderPoint(_ point: CGPoint) -> WindowInfo? {
        let windows = visibleWindows()

        // Search in Z-order (already sorted front to back)
        return windows.first { window in
            // Check if point is within window bounds
            // CGWindowList returns coordinates in Quartz space (origin at top-left)
            // which matches NSEvent.mouseLocation, so no conversion needed
            window.frame.contains(point)
        }
    }

    /// Returns all windows that intersect with the given rect.
    /// Useful for finding windows within a selection area.
    /// - Parameter rect: Rectangle in global screen coordinates
    /// - Returns: Array of WindowInfo intersecting the rect, sorted by Z-order
    func windowsIntersecting(_ rect: CGRect) -> [WindowInfo] {
        let windows = visibleWindows()

        return windows.filter { window in
            window.frame.intersects(rect)
        }
    }

    /// Returns the window with the specified window ID.
    /// - Parameter windowID: The CGWindowID to find
    /// - Returns: WindowInfo for the specified window, or nil if not found
    func window(withID windowID: CGWindowID) -> WindowInfo? {
        let windows = visibleWindows()
        return windows.first { $0.windowID == windowID }
    }

    /// Clears the window cache, forcing a fresh enumeration on next call.
    func invalidateCache() {
        cachedWindows = []
        lastEnumerationTime = nil
    }

    // MARK: - Private Methods

    /// Parses the raw window list from CGWindowListCopyWindowInfo.
    /// - Parameter windowList: Raw array of window dictionaries
    /// - Returns: Array of parsed WindowInfo, filtered and sorted
    private func parseWindowList(_ windowList: [[String: Any]]) -> [WindowInfo] {
        var windows: [WindowInfo] = []

        for windowDict in windowList {
            guard let windowInfo = parseWindowInfo(windowDict) else {
                continue
            }

            // Filter out system windows (layer != 0)
            guard windowInfo.isNormalWindow else {
                continue
            }

            // Filter out own app's windows (overlay windows)
            guard !isOwnWindow(windowInfo) else {
                continue
            }

            // Filter out windows with zero alpha (invisible)
            guard windowInfo.alpha > 0 else {
                continue
            }

            // Filter out windows with empty frames
            guard windowInfo.frame.width > 0 && windowInfo.frame.height > 0 else {
                continue
            }

            windows.append(windowInfo)
        }

        // Windows are already in Z-order from CGWindowListCopyWindowInfo
        // (front to back), so no additional sorting needed
        return windows
    }

    /// Parses a single window dictionary into WindowInfo.
    /// - Parameter dict: Window dictionary from CGWindowListCopyWindowInfo
    /// - Returns: Parsed WindowInfo, or nil if parsing fails
    private func parseWindowInfo(_ dict: [String: Any]) -> WindowInfo? {
        // Extract window ID
        guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID else {
            return nil
        }

        // Extract window bounds
        guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            return nil
        }

        let frame = CGRect(x: x, y: y, width: width, height: height)

        // Extract owner name (application name)
        let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""

        // Extract window name (title)
        let windowName = dict[kCGWindowName as String] as? String ?? ""

        // Extract window layer
        let windowLayer = dict[kCGWindowLayer as String] as? Int ?? 0

        // Extract on-screen status
        let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? true

        // Extract alpha value
        let alpha = dict[kCGWindowAlpha as String] as? Double ?? 1.0

        return WindowInfo(
            windowID: windowID,
            frame: frame,
            ownerName: ownerName,
            windowName: windowName,
            windowLayer: windowLayer,
            isOnScreen: isOnScreen,
            alpha: alpha
        )
    }

    /// Checks if a window belongs to this application.
    /// - Parameter windowInfo: The window to check
    /// - Returns: True if the window is from this app
    private func isOwnWindow(_ windowInfo: WindowInfo) -> Bool {
        // Check if owner name matches our app name
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String

        if let appName = appName, windowInfo.ownerName == appName {
            return true
        }

        if let displayName = displayName, windowInfo.ownerName == displayName {
            return true
        }

        // Additional check: compare with process name
        let processName = ProcessInfo.processInfo.processName
        if windowInfo.ownerName == processName {
            return true
        }

        return false
    }
}

// MARK: - Coordinate Conversion Helpers

extension WindowDetector {
    /// Converts a point from Cocoa coordinate system (origin at bottom-left)
    /// to Quartz coordinate system (origin at top-left).
    /// - Parameters:
    ///   - point: Point in Cocoa coordinates
    ///   - screenHeight: The screen height for conversion
    /// - Returns: Point in Quartz coordinates
    static func cocoaToQuartz(_ point: CGPoint, screenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: screenHeight - point.y)
    }

    /// Converts a point from Quartz coordinate system (origin at top-left)
    /// to Cocoa coordinate system (origin at bottom-left).
    /// - Parameters:
    ///   - point: Point in Quartz coordinates
    ///   - screenHeight: The screen height for conversion
    /// - Returns: Point in Cocoa coordinates
    static func quartzToCocoa(_ point: CGPoint, screenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: screenHeight - point.y)
    }

    /// Converts a rect from Cocoa coordinate system to Quartz coordinate system.
    /// - Parameters:
    ///   - rect: Rectangle in Cocoa coordinates
    ///   - screenHeight: The screen height for conversion
    /// - Returns: Rectangle in Quartz coordinates
    static func cocoaToQuartz(_ rect: CGRect, screenHeight: CGFloat) -> CGRect {
        let y = screenHeight - rect.maxY
        return CGRect(x: rect.minX, y: y, width: rect.width, height: rect.height)
    }

    /// Converts a rect from Quartz coordinate system to Cocoa coordinate system.
    /// - Parameters:
    ///   - rect: Rectangle in Quartz coordinates
    ///   - screenHeight: The screen height for conversion
    /// - Returns: Rectangle in Cocoa coordinates
    static func quartzToCocoa(_ rect: CGRect, screenHeight: CGFloat) -> CGRect {
        let y = screenHeight - rect.maxY
        return CGRect(x: rect.minX, y: y, width: rect.width, height: rect.height)
    }

    // MARK: - Deprecated MainActor Methods

    /// Converts a point from Cocoa coordinate system to Quartz coordinate system.
    /// - Parameters:
    ///   - point: Point in Cocoa coordinates
    ///   - screen: The screen for reference (uses main screen if nil)
    /// - Returns: Point in Quartz coordinates
    @MainActor
    static func cocoaToQuartz(_ point: CGPoint, on screen: NSScreen?) -> CGPoint {
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen = targetScreen else {
            return point
        }
        return cocoaToQuartz(point, screenHeight: targetScreen.frame.height)
    }

    /// Converts a point from Quartz coordinate system to Cocoa coordinate system.
    /// - Parameters:
    ///   - point: Point in Quartz coordinates
    ///   - screen: The screen for reference (uses main screen if nil)
    /// - Returns: Point in Cocoa coordinates
    @MainActor
    static func quartzToCocoa(_ point: CGPoint, on screen: NSScreen?) -> CGPoint {
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen = targetScreen else {
            return point
        }
        return quartzToCocoa(point, screenHeight: targetScreen.frame.height)
    }
}
