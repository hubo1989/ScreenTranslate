import AppKit
import Foundation

/// Manages all pinned screenshot windows.
/// Provides centralized control over pinned window lifecycle.
@MainActor
final class PinnedWindowsManager {
    // MARK: - Singleton

    static let shared = PinnedWindowsManager()

    // MARK: - Properties

    /// All currently pinned windows
    private(set) var pinnedWindows: [UUID: PinnedWindow] = [:]

    /// Maximum number of pinned windows allowed
    private let maxPinnedWindows = 5

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Pins a screenshot with its annotations.
    /// - Parameters:
    ///   - screenshot: The screenshot to pin
    ///   - annotations: The annotations to include
    /// - Returns: The created pinned window, or nil if limit reached
    @discardableResult
    func pinScreenshot(_ screenshot: Screenshot, annotations: [Annotation]) -> PinnedWindow? {
        // Check if already pinned
        if let existingWindow = pinnedWindows[screenshot.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return existingWindow
        }

        // Check limit
        if pinnedWindows.count >= maxPinnedWindows {
            // Show warning
            showLimitWarning()
            return nil
        }

        // Create new pinned window
        let pinnedWindow = PinnedWindow(
            screenshot: screenshot,
            annotations: annotations
        )

        pinnedWindow.onClose = { [weak self] in
            self?.unpinWindow(screenshot.id)
        }

        pinnedWindows[screenshot.id] = pinnedWindow
        pinnedWindow.show()

        return pinnedWindow
    }

    /// Unpins a screenshot by its ID.
    /// - Parameter id: The screenshot ID to unpin
    func unpinWindow(_ id: UUID) {
        guard let window = pinnedWindows[id] else { return }
        
        // Mark as programmatic close to prevent reentrancy
        window.isProgrammaticClose = true
        window.close()
        pinnedWindows.removeValue(forKey: id)
    }

    /// Unpins all pinned windows.
    func unpinAll() {
        // Get all IDs first to avoid dictionary mutation during iteration
        let windowIds = Array(pinnedWindows.keys)
        for id in windowIds {
            pinnedWindows[id]?.close()
        }
        pinnedWindows.removeAll()
    }

    /// Checks if a screenshot is currently pinned.
    /// - Parameter id: The screenshot ID to check
    /// - Returns: True if pinned, false otherwise
    func isPinned(_ id: UUID) -> Bool {
        pinnedWindows[id] != nil
    }

    /// Returns the number of currently pinned windows.
    var pinnedCount: Int {
        pinnedWindows.count
    }

    /// Brings a pinned window to front.
    /// - Parameter id: The screenshot ID to bring to front
    func bringToFront(_ id: UUID) {
        pinnedWindows[id]?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Private Helpers

    private func showLimitWarning() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(
            "pinned.limit.title",
            value: "Pin Limit Reached",
            comment: "Alert title when pin limit is reached"
        )
        alert.informativeText = String(
            format: NSLocalizedString(
                "pinned.limit.message",
                value: "You can pin up to %d screenshots at a time. Please unpin some first.",
                comment: "Alert message explaining pin limit"
            ),
            maxPinnedWindows
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }
}
