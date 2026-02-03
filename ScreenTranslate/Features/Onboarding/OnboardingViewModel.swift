import Foundation
import SwiftUI
import AppKit

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
    let totalSteps = 4

    /// Screen recording permission status
    var hasScreenRecordingPermission = false

    /// Accessibility permission status
    var hasAccessibilityPermission = false

    /// PaddleOCR server address
    var paddleOCRServerAddress = ""

    /// MTranServer address
    var mtranServerAddress = "localhost"

    /// MTranServer port
    var mtranServerPort = 8989

    /// Whether a translation test is in progress
    var isTestingTranslation = false

    /// Translation test result message
    var translationTestResult: String?

    /// Translation test success status
    var translationTestSuccess = false

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
            // Configuration step - optional, always can proceed
            return true
        case 3:
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
        checkPermissions()
    }

    // MARK: - Actions

    /// Moves to the next step if validation passes
    func goToNextStep() {
        guard canGoNext else { return }
        guard currentStep < totalSteps - 1 else {
            // Complete onboarding
            completeOnboarding()
            return
        }
        currentStep += 1
    }

    /// Moves to the previous step
    func goToPreviousStep() {
        guard canGoPrevious else { return }
        currentStep -= 1
    }

    /// Checks all permission statuses
    func checkPermissions() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        hasAccessibilityPermission = AccessibilityPermissionChecker.hasPermission
    }

    /// Requests screen recording permission
    func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
        // Recheck after a short delay
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            checkPermissions()
        }
    }

    /// Opens System Settings for screen recording permission
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Requests accessibility permission
    func requestAccessibilityPermission() {
        // Show system prompt
        _ = AccessibilityPermissionChecker.requestPermission()
        // Recheck after a short delay
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            checkPermissions()
        }
    }

    /// Opens System Settings for accessibility permission
    func openAccessibilitySettings() {
        AccessibilityPermissionChecker.openAccessibilitySettings()
    }

    /// Tests the translation configuration with a sample request
    func testTranslation() async {
        isTestingTranslation = true
        translationTestResult = nil
        translationTestSuccess = false

        // Test with sample text
        let testText = "Hello"

        do {
            // Try Apple Translation (always available as fallback)
            let engine = TranslationEngine.shared
            let result = try await engine.translate(testText, to: .chineseSimplified)

            translationTestResult = String(
                format: NSLocalizedString("onboarding.test.success", comment: ""),
                testText,
                result.translatedText
            )
            translationTestSuccess = true
        } catch {
            translationTestResult = String(
                format: NSLocalizedString("onboarding.test.failed", comment: ""),
                error.localizedDescription
            )
            translationTestSuccess = false
        }

        isTestingTranslation = false
    }

    /// Saves the configuration and completes onboarding
    private func completeOnboarding() {
        // Save configuration if addresses were provided
        if !paddleOCRServerAddress.isEmpty {
            // Note: PaddleOCR is selected via ocrEngine in AppSettings
            // The server address would be used when PaddleOCR engine is active
        }

        if !mtranServerAddress.isEmpty {
            // Note: MTranServer configuration would be saved here
            // when MTranServer engine is selected
        }

        // Mark onboarding as completed
        settings.onboardingCompleted = true

        // Notify window to close
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }

    /// Skips optional configuration
    func skipConfiguration() {
        goToNextStep()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when onboarding is completed
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
