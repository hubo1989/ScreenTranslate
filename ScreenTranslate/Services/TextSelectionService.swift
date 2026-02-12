import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

/// Result of text selection capture
struct TextSelectionResult: Sendable {
    /// The captured selected text
    let text: String
    /// The name of the source application (if available)
    let sourceApplication: String?
    /// The bundle identifier of the source application (if available)
    let sourceBundleIdentifier: String?
}

/// Service for capturing selected text from any application.
/// Uses clipboard-based capture with Cmd+C simulation to reliably get selected text.
actor TextSelectionService {

    // MARK: - Types

    /// Errors that can occur during text selection capture
    enum CaptureError: LocalizedError, Sendable {
        /// No text was selected in the active application
        case noSelection
        /// Failed to simulate keyboard shortcut
        case keyboardSimulationFailed
        /// Failed to access clipboard
        case clipboardAccessFailed
        /// Failed to restore original clipboard content
        case clipboardRestoreFailed
        /// The operation timed out
        case timeout
        /// Accessibility permission is required but not granted
        case accessibilityPermissionDenied

        var errorDescription: String? {
            switch self {
            case .noSelection:
                return NSLocalizedString(
                    "error.text.selection.no.selection",
                    value: "No text is currently selected",
                    comment: ""
                )
            case .keyboardSimulationFailed:
                return NSLocalizedString(
                    "error.text.selection.keyboard.failed",
                    value: "Failed to simulate keyboard shortcut",
                    comment: ""
                )
            case .clipboardAccessFailed:
                return NSLocalizedString(
                    "error.text.selection.clipboard.access.failed",
                    value: "Failed to access clipboard",
                    comment: ""
                )
            case .clipboardRestoreFailed:
                return NSLocalizedString(
                    "error.text.selection.clipboard.restore.failed",
                    value: "Failed to restore original clipboard content",
                    comment: ""
                )
            case .timeout:
                return NSLocalizedString(
                    "error.text.selection.timeout",
                    value: "Text capture operation timed out",
                    comment: ""
                )
            case .accessibilityPermissionDenied:
                return NSLocalizedString(
                    "error.text.selection.accessibility.denied",
                    value: "Accessibility permission is required to capture text",
                    comment: ""
                )
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noSelection:
                return NSLocalizedString(
                    "error.text.selection.no.selection.recovery",
                    value: "Select some text in any application and try again",
                    comment: ""
                )
            case .keyboardSimulationFailed, .clipboardAccessFailed:
                return NSLocalizedString(
                    "error.text.selection.general.recovery",
                    value: "Please try again",
                    comment: ""
                )
            case .clipboardRestoreFailed:
                return NSLocalizedString(
                    "error.text.selection.clipboard.restore.recovery",
                    value: "Your original clipboard content may have been replaced",
                    comment: ""
                )
            case .timeout:
                return NSLocalizedString(
                    "error.text.selection.timeout.recovery",
                    value: "The application may be busy. Please try again",
                    comment: ""
                )
            case .accessibilityPermissionDenied:
                return NSLocalizedString(
                    "error.text.selection.accessibility.denied.recovery",
                    value: "Grant accessibility permission in System Settings > Privacy & Security > Accessibility",
                    comment: ""
                )
            }
        }
    }

    // MARK: - Properties

    /// Time to wait for clipboard to be updated after Cmd+C
    private let clipboardWaitTimeout: TimeInterval

    /// Number of times to check clipboard before giving up
    private let clipboardCheckRetries: Int

    /// Delay between clipboard checks
    private let clipboardCheckInterval: TimeInterval

    // MARK: - Initialization

    init(
        clipboardWaitTimeout: TimeInterval = 2.0,
        clipboardCheckRetries: Int = 20,
        clipboardCheckInterval: TimeInterval = 0.1
    ) {
        self.clipboardWaitTimeout = clipboardWaitTimeout
        self.clipboardCheckRetries = clipboardCheckRetries
        self.clipboardCheckInterval = clipboardCheckInterval
    }

    // MARK: - Public API

    /// Captures currently selected text from the active application.
    /// - Returns: A TextSelectionResult containing the selected text and source application info
    /// - Throws: CaptureError if the capture fails
    func captureSelectedText() async throws -> TextSelectionResult {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw CaptureError.accessibilityPermissionDenied
        }

        // Get source application info before capturing
        let sourceAppInfo = getActiveApplicationInfo()

        // Save current clipboard content
        let savedClipboard = try saveClipboardContent()

        // Clear clipboard to detect when new content is pasted
        clearClipboard()

        // Simulate Cmd+C to copy selected text
        try simulateCopyShortcut()

        // Wait for clipboard to be updated with selected text
        let capturedText = try await waitForClipboardUpdate(previousContent: savedClipboard?.string)

        // Restore original clipboard content
        if let saved = savedClipboard {
            do {
                try restoreClipboardContent(saved)
            } catch {
                // Log but don't fail - we still got the text
                print("Warning: Failed to restore clipboard: \(error)")
            }
        }

        // Validate we got some text
        guard !capturedText.isEmpty else {
            throw CaptureError.noSelection
        }

        return TextSelectionResult(
            text: capturedText,
            sourceApplication: sourceAppInfo.name,
            sourceBundleIdentifier: sourceAppInfo.bundleIdentifier
        )
    }

    /// Checks if text selection capture is likely to work.
    /// Returns false if accessibility permission is not granted.
    var canCapture: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Private Helpers

    /// Information about the active application
    private struct ApplicationInfo {
        let name: String?
        let bundleIdentifier: String?
    }

    /// Gets information about the currently active application.
    private func getActiveApplicationInfo() -> ApplicationInfo {
        let workspace = NSWorkspace.shared
        let frontmostApp = workspace.frontmostApplication

        return ApplicationInfo(
            name: frontmostApp?.localizedName,
            bundleIdentifier: frontmostApp?.bundleIdentifier
        )
    }

    /// Represents saved clipboard content
    private struct SavedClipboardContent: Sendable {
        let string: String?
        let data: Data?
        let types: [NSPasteboard.PasteboardType]
    }

    /// Saves the current clipboard content for later restoration.
    private func saveClipboardContent() throws -> SavedClipboardContent? {
        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types, !types.isEmpty else {
            return nil
        }

        // Get string content if available
        let stringContent = pasteboard.string(forType: .string)

        // Get data for each type (for non-string types like images)
        var dataContent: Data?
        if let firstType = types.first {
            dataContent = pasteboard.data(forType: firstType)
        }

        return SavedClipboardContent(
            string: stringContent,
            data: dataContent,
            types: types
        )
    }

    /// Clears the clipboard content.
    private func clearClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
    }

    /// Simulates Cmd+C keyboard shortcut to copy selected text.
    private func simulateCopyShortcut() throws {
        // Create Cmd+C key down event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 8, // kVK_ANSI_C
            keyDown: true
        ) else {
            throw CaptureError.keyboardSimulationFailed
        }

        // Create Cmd+C key up event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 8, // kVK_ANSI_C
            keyDown: false
        ) else {
            throw CaptureError.keyboardSimulationFailed
        }

        // Set Command flag for both events
        let cmdFlag = CGEventFlags.maskCommand
        keyDownEvent.flags = cmdFlag
        keyUpEvent.flags = cmdFlag

        // Post events
        let loc = CGEventTapLocation.cghidEventTap
        keyDownEvent.post(tap: loc)
        keyUpEvent.post(tap: loc)
    }

    /// Waits for clipboard to be updated with new content.
    /// - Parameter previousContent: The previous clipboard content to compare against
    /// - Returns: The new clipboard content
    /// - Throws: CaptureError if timeout or no change detected
    private func waitForClipboardUpdate(previousContent: String?) async throws -> String {
        for _ in 0..<clipboardCheckRetries {
            // Small delay to allow clipboard to update
            try await Task.sleep(nanoseconds: UInt64(clipboardCheckInterval * 1_000_000_000))

            let pasteboard = NSPasteboard.general

            // Check if there's string content
            guard let currentContent = pasteboard.string(forType: .string) else {
                continue
            }

            // If content changed from previous, we got the selection
            if currentContent != previousContent && !currentContent.isEmpty {
                return currentContent
            }
        }

        // No change detected - either nothing was selected or copy failed
        throw CaptureError.noSelection
    }

    /// Restores the saved clipboard content.
    private func restoreClipboardContent(_ saved: SavedClipboardContent) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Restore string content if it existed
        if let stringContent = saved.string {
            pasteboard.setString(stringContent, forType: .string)
        } else if let data = saved.data, let firstType = saved.types.first {
            // Restore data content
            pasteboard.setData(data, forType: firstType)
        }

        // Verify restoration succeeded
        if saved.string != nil {
            guard pasteboard.string(forType: .string) == saved.string else {
                throw CaptureError.clipboardRestoreFailed
            }
        }
    }
}

// MARK: - Shared Instance

extension TextSelectionService {
    /// Shared instance for convenience
    static let shared = TextSelectionService()
}
