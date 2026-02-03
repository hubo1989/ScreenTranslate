import Foundation
import CoreGraphics
import AppKit
@preconcurrency import ScreenCaptureKit

/// Represents a connected display for capture targeting.
/// Immutable value type that maps SCDisplay data to app-specific display info.
struct DisplayInfo: Identifiable, Hashable, Sendable {
    /// System display identifier (from SCDisplay.displayID)
    let id: CGDirectDisplayID

    /// User-visible display name
    let name: String

    /// Position and size in global screen coordinates
    let frame: CGRect

    /// Retina scale factor (1.0, 2.0, 3.0)
    let scaleFactor: CGFloat

    /// Whether this is the main/primary display
    let isPrimary: Bool

    // MARK: - Computed Properties

    /// Formatted resolution string (e.g., "2560 x 1440")
    var resolution: String {
        let width = Int(frame.width * scaleFactor)
        let height = Int(frame.height * scaleFactor)
        return "\(width) x \(height)"
    }

    /// Whether this display has a Retina scale factor
    var isRetina: Bool {
        scaleFactor > 1.0
    }

    /// The pixel dimensions of the display
    var pixelSize: CGSize {
        CGSize(
            width: frame.width * scaleFactor,
            height: frame.height * scaleFactor
        )
    }

    // MARK: - Initialization

    /// Creates DisplayInfo from an SCDisplay and optional NSScreen
    /// - Parameters:
    ///   - scDisplay: The ScreenCaptureKit display object
    ///   - screen: The corresponding NSScreen for additional metadata (optional)
    @MainActor
    init(scDisplay: SCDisplay, screen: NSScreen?) {
        self.id = scDisplay.displayID
        // Use scDisplay.frame for consistent POINT coordinates
        // Note: scDisplay.width/height are in PIXELS, but frame is in POINTS
        self.frame = scDisplay.frame

        // Derive name from display ID or screen
        if let screen = screen {
            self.name = screen.localizedName
            self.scaleFactor = screen.backingScaleFactor
            self.isPrimary = screen == NSScreen.main
        } else {
            self.name = "Display \(scDisplay.displayID)"
            self.scaleFactor = 1.0
            self.isPrimary = CGDisplayIsMain(scDisplay.displayID) != 0
        }
    }

    /// Creates DisplayInfo with explicit values (for testing or previews)
    init(
        id: CGDirectDisplayID,
        name: String,
        frame: CGRect,
        scaleFactor: CGFloat = 2.0,
        isPrimary: Bool = true
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.scaleFactor = scaleFactor
        self.isPrimary = isPrimary
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Display Matching

extension DisplayInfo {
    /// Finds the NSScreen that corresponds to this display
    @MainActor
    var matchingScreen: NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return screenNumber == id
        }
    }
}
