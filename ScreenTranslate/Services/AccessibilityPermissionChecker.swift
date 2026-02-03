import Foundation
import ApplicationServices
import AppKit

/// Utility for checking and requesting accessibility permission for global hotkeys.
enum AccessibilityPermissionChecker {
    /// Checks if the app has accessibility permission.
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Requests accessibility permission by showing system prompt.
    /// Returns whether permission is granted after the prompt.
    @discardableResult
    static func requestPermission() -> Bool {
        // Use the string literal directly (kAXTrustedCheckOptionPrompt = "AXTrustedCheckOptionPrompt")
        let options: CFDictionary = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings to Accessibility pane.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
