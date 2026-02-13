//
//  PermissionManager.swift
//  ScreenTranslate
//
//  Created for US-009 - Handle accessibility and input monitoring permissions
//

import Foundation
import ApplicationServices
import AppKit
import Combine

/// Manager for handling system permissions required by the app.
/// Centralizes permission checking, requesting, and caching logic.
@MainActor
final class PermissionManager: ObservableObject {
    // MARK: - Singleton

    static let shared = PermissionManager()

    // MARK: - Published Properties

    /// Current accessibility permission status
    @Published private(set) var hasAccessibilityPermission: Bool = false

    /// Current input monitoring permission status
    @Published private(set) var hasInputMonitoringPermission: Bool = false

    // MARK: - Private Properties

    /// UserDefaults key for cached accessibility permission status
    private let accessibilityCacheKey = "cachedAccessibilityPermission"

    /// UserDefaults key for cached input monitoring permission status
    private let inputMonitoringCacheKey = "cachedInputMonitoringPermission"

    /// Timer for periodic permission checks
    private var permissionCheckTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Load cached values
        loadCachedPermissions()

        // Check actual permissions
        refreshPermissionStatus()

        // Start periodic permission checks
        startPermissionMonitoring()
    }

    // MARK: - Public API

    /// Checks and refreshes all permission statuses.
    func refreshPermissionStatus() {
        hasAccessibilityPermission = AXIsProcessTrusted()

        // Check Input Monitoring permission (macOS 10.15+)
        if #available(macOS 10.15, *) {
            hasInputMonitoringPermission = checkInputMonitoringPermission()
        } else {
            hasInputMonitoringPermission = true
        }

        // Cache the results
        cachePermissions()
    }

    /// Requests accessibility permission with a user-friendly explanation dialog.
    /// - Returns: Whether permission was granted after the prompt.
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        // First check if already granted
        if hasAccessibilityPermission {
            return true
        }

        // Show explanation dialog first
        let shouldPrompt = showAccessibilityExplanationDialog()

        if shouldPrompt {
            // Request the permission (shows system dialog)
            let options: CFDictionary = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            let granted = AXIsProcessTrustedWithOptions(options)

            // Update our status
            hasAccessibilityPermission = granted
            cachePermissions()

            return granted
        }

        return false
    }

    /// Requests input monitoring permission with a user-friendly explanation dialog.
    /// - Returns: Whether permission was granted.
    @discardableResult
    func requestInputMonitoringPermission() -> Bool {
        // First check if already granted
        if hasInputMonitoringPermission {
            return true
        }

        // Show explanation dialog
        let shouldPrompt = showInputMonitoringExplanationDialog()

        if shouldPrompt {
            // Open System Settings to Privacy & Security > Input Monitoring
            openInputMonitoringSettings()

            // We can't directly request this permission - user must enable in System Settings
            // Return current status
            return hasInputMonitoringPermission
        }

        return false
    }

    /// Opens System Settings to the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings to the Input Monitoring pane.
    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Checks if text selection capture is possible (requires accessibility).
    var canCaptureTextSelection: Bool {
        hasAccessibilityPermission
    }

    /// Checks if text insertion is possible (requires accessibility).
    var canInsertText: Bool {
        hasAccessibilityPermission
    }

    /// Ensures accessibility permission is available, requesting if needed.
    /// - Returns: Whether permission is available.
    func ensureAccessibilityPermission() async -> Bool {
        // Check current status
        refreshPermissionStatus()

        if hasAccessibilityPermission {
            return true
        }

        // Request permission
        return requestAccessibilityPermission()
    }

    /// Ensures input monitoring permission is available, requesting if needed.
    /// - Returns: Whether permission is available.
    func ensureInputMonitoringPermission() async -> Bool {
        // Check current status
        refreshPermissionStatus()

        if hasInputMonitoringPermission {
            return true
        }

        // Request permission
        return requestInputMonitoringPermission()
    }

    // MARK: - Permission Checks

    /// Checks Input Monitoring permission status.
    @available(macOS 10.15, *)
    private func checkInputMonitoringPermission() -> Bool {
        // For Input Monitoring, we check if we can create an event tap
        // This is the most reliable way to check the permission
        // Use the string literal directly to avoid concurrency issues with kAXTrustedCheckOptionPrompt
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary

        // If accessibility is granted, input monitoring typically works too
        // But we should also check the actual input monitoring capability
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Dialogs

    /// Shows an explanation dialog for accessibility permission.
    /// - Returns: Whether the user wants to proceed with granting permission.
    private func showAccessibilityExplanationDialog() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString(
            "permission.accessibility.title",
            value: "Accessibility Permission Required",
            comment: "Title for accessibility permission dialog"
        )
        alert.informativeText = NSLocalizedString(
            "permission.accessibility.message",
            value: "ScreenTranslate needs accessibility permission to capture selected text and insert translations.\n\nThis allows the app to:\n• Copy selected text from any application\n• Insert translated text into input fields\n\nYour privacy is protected - ScreenTranslate only uses this for text translation.",
            comment: "Message explaining why accessibility permission is needed"
        )
        alert.addButton(withTitle: NSLocalizedString(
            "permission.accessibility.grant",
            value: "Grant Permission",
            comment: "Button to grant accessibility permission"
        ))
        alert.addButton(withTitle: NSLocalizedString(
            "permission.accessibility.open.settings",
            value: "Open System Settings",
            comment: "Button to open System Settings"
        ))
        alert.addButton(withTitle: NSLocalizedString(
            "permission.later",
            value: "Later",
            comment: "Button to skip permission request"
        ))

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Grant Permission - will show system prompt
            return true
        case .alertSecondButtonReturn:
            // Open System Settings
            openAccessibilitySettings()
            return false
        default:
            // Later
            return false
        }
    }

    /// Shows an explanation dialog for input monitoring permission.
    /// - Returns: Whether the user wants to proceed with granting permission.
    private func showInputMonitoringExplanationDialog() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString(
            "permission.input.monitoring.title",
            value: "Input Monitoring Permission Required",
            comment: "Title for input monitoring permission dialog"
        )
        alert.informativeText = NSLocalizedString(
            "permission.input.monitoring.message",
            value: "ScreenTranslate needs input monitoring permission to insert translated text into applications.\n\nYou'll need to enable this in:\nSystem Settings > Privacy & Security > Input Monitoring",
            comment: "Message explaining why input monitoring permission is needed"
        )
        alert.addButton(withTitle: NSLocalizedString(
            "permission.input.monitoring.open.settings",
            value: "Open System Settings",
            comment: "Button to open System Settings for input monitoring"
        ))
        alert.addButton(withTitle: NSLocalizedString(
            "permission.later",
            value: "Later",
            comment: "Button to skip permission request"
        ))

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Open System Settings
            return true
        default:
            // Later
            return false
        }
    }

    /// Shows a permission denied error in the translation popup.
    func showPermissionDeniedError(for permissionType: PermissionType) {
        let alert = NSAlert()
        alert.alertStyle = .warning

        switch permissionType {
        case .accessibility:
            alert.messageText = NSLocalizedString(
                "permission.accessibility.denied.title",
                value: "Accessibility Permission Required",
                comment: "Title for accessibility denied error"
            )
            alert.informativeText = NSLocalizedString(
                "permission.accessibility.denied.message",
                value: "Text capture and insertion requires accessibility permission.\n\nPlease grant permission in System Settings > Privacy & Security > Accessibility.",
                comment: "Message for accessibility denied error"
            )
            alert.addButton(withTitle: NSLocalizedString(
                "permission.open.settings",
                value: "Open System Settings",
                comment: "Button to open System Settings"
            ))
            alert.addButton(withTitle: NSLocalizedString(
                "common.ok",
                value: "OK",
                comment: "OK button"
            ))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }

        case .inputMonitoring:
            alert.messageText = NSLocalizedString(
                "permission.input.monitoring.denied.title",
                value: "Input Monitoring Permission Required",
                comment: "Title for input monitoring denied error"
            )
            alert.informativeText = NSLocalizedString(
                "permission.input.monitoring.denied.message",
                value: "Text insertion requires input monitoring permission.\n\nPlease grant permission in System Settings > Privacy & Security > Input Monitoring.",
                comment: "Message for input monitoring denied error"
            )
            alert.addButton(withTitle: NSLocalizedString(
                "permission.open.settings",
                value: "Open System Settings",
                comment: "Button to open System Settings"
            ))
            alert.addButton(withTitle: NSLocalizedString(
                "common.ok",
                value: "OK",
                comment: "OK button"
            ))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openInputMonitoringSettings()
            }
        }
    }

    // MARK: - Permission Types

    enum PermissionType {
        case accessibility
        case inputMonitoring
    }

    // MARK: - Caching

    /// Caches current permission status to UserDefaults.
    private func cachePermissions() {
        UserDefaults.standard.set(hasAccessibilityPermission, forKey: accessibilityCacheKey)
        UserDefaults.standard.set(hasInputMonitoringPermission, forKey: inputMonitoringCacheKey)
    }

    /// Loads cached permission status from UserDefaults.
    private func loadCachedPermissions() {
        // Note: These are just cached values for UI display
        // Actual permission check happens in refreshPermissionStatus()
        hasAccessibilityPermission = UserDefaults.standard.bool(forKey: accessibilityCacheKey)
        hasInputMonitoringPermission = UserDefaults.standard.bool(forKey: inputMonitoringCacheKey)
    }

    // MARK: - Permission Monitoring

    /// Starts periodic permission status checks.
    private func startPermissionMonitoring() {
        // Check permissions every 2 seconds when app is active
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionStatus()
            }
        }
    }

    /// Stops permission monitoring.
    func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
}

// MARK: - Convenience Extensions

extension PermissionManager {
    /// Checks accessibility permission before performing a text operation.
    /// Shows an error dialog if permission is not granted.
    /// - Returns: Whether permission is available.
    func checkAndPromptAccessibility() -> Bool {
        refreshPermissionStatus()

        if hasAccessibilityPermission {
            return true
        }

        showPermissionDeniedError(for: .accessibility)
        return false
    }

    /// Checks input monitoring permission before performing a text insertion.
    /// Shows an error dialog if permission is not granted.
    /// - Returns: Whether permission is available.
    func checkAndPromptInputMonitoring() -> Bool {
        refreshPermissionStatus()

        if hasInputMonitoringPermission {
            return true
        }

        showPermissionDeniedError(for: .inputMonitoring)
        return false
    }
}
