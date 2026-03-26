import Foundation
import SwiftUI
import AppKit
@preconcurrency import ScreenCaptureKit
import Translation
import os.log

/// ViewModel for the first launch onboarding experience.
@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - Properties

    /// Reference to shared app settings
    private let settings: AppSettings

    /// Current step in the onboarding flow (0-indexed)
    var currentStep = 0

    /// Total number of steps in the onboarding flow
    let totalSteps = 3

    /// Screen recording permission status
    var hasScreenRecordingPermission = false

    /// Accessibility permission status
    var hasAccessibilityPermission = false

    /// Whether user has skipped the permissions step
    var hasSkippedPermissions = false

    /// Whether permission check has timed out (30s polling exceeded)
    var permissionCheckTimedOut = false

    /// Type of permission being requested
    enum PermissionType {
        case screenRecording
        case accessibility
    }

    /// Task for permission checking (stored for cancellation)
    private var permissionCheckTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Whether we can move to the next step
    var canGoNext: Bool {
        switch currentStep {
        case 0:
            // Welcome step - always can proceed
            return true
        case 1:
            // Permissions step - need both permissions
            return hasScreenRecordingPermission && hasAccessibilityPermission
        case 2:
            // Complete step - can finish
            return true
        default:
            return false
        }
    }

    /// Whether we can move to the previous step
    var canGoPrevious: Bool {
        currentStep > 0
    }

    /// Whether this is the last step
    var isLastStep: Bool {
        currentStep == totalSteps - 1
    }

    // MARK: - Initialization

    init(settings: AppSettings = .shared) {
        self.settings = settings
        Task {
            await MainActor.run {
                // Only check accessibility permission on init (no system dialog)
                hasAccessibilityPermission = AccessibilityPermissionChecker.hasPermission
            }
        }
    }

    // MARK: - Actions

    /// Moves to the next step if validation passes
    func goToNextStep() {
        guard canGoNext else { return }
        guard currentStep < totalSteps - 1 else {
            completeOnboarding()
            return
        }
        currentStep += 1
        if currentStep == 1 {
            checkPermissions()
        }
    }

    /// Moves to the previous step
    func goToPreviousStep() {
        guard canGoPrevious else { return }
        currentStep -= 1
        if currentStep == 1 {
            checkPermissions()
        }
    }

    /// Skips the permissions step and completes onboarding
    func skipPermissions() {
        hasSkippedPermissions = true
        completeOnboarding()
    }

    /// Checks all permission statuses
    func checkPermissions() {
        hasAccessibilityPermission = AccessibilityPermissionChecker.hasPermission
        permissionCheckTimedOut = false

        // Check screen recording permission using async method
        Task {
            hasScreenRecordingPermission = await checkScreenRecordingPermission()
        }
    }

    /// Checks screen recording permission using ScreenCaptureKit for reliable detection
    private func checkScreenRecordingPermission() async -> Bool {
        // First do a quick check with CGPreflightScreenCaptureAccess
        if !CGPreflightScreenCaptureAccess() {
            return false
        }

        // Verify by actually trying to get shareable content
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            return false
        }
    }

    /// Requests screen recording permission
    func requestScreenRecordingPermission() {
        // First check if already granted
        if CGPreflightScreenCaptureAccess() {
            hasScreenRecordingPermission = true
            return
        }

        // Request permission - CGRequestScreenCaptureAccess() returns true if granted
        let granted = CGRequestScreenCaptureAccess()
        if granted {
            hasScreenRecordingPermission = true
            return
        }

        // If not granted, open System Settings
        openScreenRecordingSettings()

        // Start polling for permission status
        permissionCheckTimedOut = false
        startPermissionCheck(for: .screenRecording)
    }

    /// Opens System Settings for screen recording permission
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Requests accessibility permission - triggers system dialog only
    func requestAccessibilityPermission() {
        // Check current status first
        if AccessibilityPermissionChecker.hasPermission {
            hasAccessibilityPermission = true
            return
        }

        // Request accessibility - triggers system dialog (will guide user to settings if needed)
        _ = AccessibilityPermissionChecker.requestPermission()
        // Start checking for permission
        permissionCheckTimedOut = false
        startPermissionCheck(for: .accessibility)
    }

    /// Opens System Settings for accessibility permission
    func openAccessibilitySettings() {
        AccessibilityPermissionChecker.openAccessibilitySettings()
    }

    /// Starts checking for permission status periodically
    private func startPermissionCheck(for type: PermissionType) {
        // Cancel any existing permission check task
        permissionCheckTask?.cancel()

        permissionCheckTask = Task {
            for _ in 0..<60 {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    // Task was cancelled
                    return
                }

                switch type {
                case .screenRecording:
                    let granted = await checkScreenRecordingPermission()
                    if granted {
                        hasScreenRecordingPermission = true
                        permissionCheckTask = nil
                        return
                    }

                case .accessibility:
                    let granted = AccessibilityPermissionChecker.hasPermission
                    if granted {
                        hasAccessibilityPermission = granted
                        permissionCheckTask = nil
                        return
                    }
                }
            }
            // Polling timed out after 30 seconds
            permissionCheckTimedOut = true
        }
    }

    private func completeOnboarding() {
        settings.onboardingCompleted = true
        if hasSkippedPermissions {
            settings.userSkippedPermissions = true
        }
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when onboarding is completed
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
