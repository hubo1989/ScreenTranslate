import Foundation
import SwiftUI
import AppKit
@preconcurrency import ScreenCaptureKit
import Translation
import os.log
import PermissionFlow

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
                // Check all permissions on init
                checkPermissions()
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

    /// Skips the permissions step and navigates to the complete step
    func skipPermissions() {
        hasSkippedPermissions = true
        permissionCheckTask?.cancel()
        permissionCheckTask = nil
        currentStep = totalSteps - 1
    }

    /// Checks all permission statuses
    func checkPermissions() {
        hasAccessibilityPermission = PermissionStatusRegistry.provider(for: .accessibility).authorizationState() == .granted
        hasScreenRecordingPermission = PermissionStatusRegistry.provider(for: .screenRecording).authorizationState() == .granted
        permissionCheckTimedOut = false
    }

    /// Requests screen recording permission
    func requestScreenRecordingPermission() {
        if PermissionStatusRegistry.provider(for: .screenRecording).authorizationState() == .granted {
            hasScreenRecordingPermission = true
            return
        }
        startPermissionCheck(for: .screenRecording)
    }

    /// Requests accessibility permission - triggers system dialog only
    func requestAccessibilityPermission() {
        if PermissionStatusRegistry.provider(for: .accessibility).authorizationState() == .granted {
            hasAccessibilityPermission = true
            return
        }

        // Just start polling, let PermissionFlow handle the drag & drop authorization
        startPermissionCheck(for: .accessibility)
    }

    /// Starts checking for permission status periodically
    private func startPermissionCheck(for type: PermissionType) {
        permissionCheckTask?.cancel()

        permissionCheckTask = Task {
            for _ in 0..<150 {
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }

                switch type {
                case .screenRecording:
                    let isGranted = PermissionStatusRegistry.provider(for: .screenRecording).authorizationState() == .granted
                    if isGranted {
                        hasScreenRecordingPermission = true
                        permissionCheckTask = nil
                        return
                    }

                case .accessibility:
                    let isGranted = PermissionStatusRegistry.provider(for: .accessibility).authorizationState() == .granted
                    if isGranted {
                        hasAccessibilityPermission = true
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
        settings.userSkippedPermissions =
            hasSkippedPermissions &&
            (!hasScreenRecordingPermission || !hasAccessibilityPermission)
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when onboarding is completed
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let onboardingDismissed = Notification.Name("onboardingDismissed")
}
