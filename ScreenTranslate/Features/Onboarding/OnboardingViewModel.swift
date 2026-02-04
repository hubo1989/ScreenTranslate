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
    let totalSteps = 4

    /// Screen recording permission status
    var hasScreenRecordingPermission = false

    /// Accessibility permission status
    var hasAccessibilityPermission = false

    /// PaddleOCR server address
    var paddleOCRServerAddress = ""

    var mtranServerURL = "localhost:8989"

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
        Task {
            await MainActor.run {
                checkPermissions()
            }
        }
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
        hasAccessibilityPermission = AccessibilityPermissionChecker.hasPermission
        Task {
            hasScreenRecordingPermission = await ScreenDetector.shared.hasPermission
        }
    }

    /// Checks screen recording permission using ScreenCaptureKit
    func checkScreenRecordingPermission() async -> Bool {
        await ScreenDetector.shared.hasPermission
    }

    /// Requests screen recording permission
    func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(300))
                let hasPermission = await checkScreenRecordingPermission()
                await MainActor.run {
                    hasScreenRecordingPermission = hasPermission
                }
                if hasPermission { break }
            }
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
        _ = AccessibilityPermissionChecker.requestPermission()
        Task {
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(500))
                checkPermissions()
                if hasAccessibilityPermission { break }
            }
        }
    }

    /// Opens System Settings for accessibility permission
    func openAccessibilitySettings() {
        AccessibilityPermissionChecker.openAccessibilitySettings()
    }

    func testTranslation() async {
        isTestingTranslation = true
        translationTestResult = nil
        translationTestSuccess = false

        let testText = "Hello"

        do {
            if let (host, port) = parseServerURL(mtranServerURL), !host.isEmpty {
                let originalHost = settings.mtranServerHost
                let originalPort = settings.mtranServerPort
                settings.mtranServerHost = host
                settings.mtranServerPort = port

                let result = try await MTranServerEngine.shared.translate(testText, to: "zh")

                settings.mtranServerHost = originalHost
                settings.mtranServerPort = originalPort

                translationTestResult = String(
                    format: NSLocalizedString("onboarding.test.success", comment: ""),
                    testText,
                    result.translatedText
                )
                translationTestSuccess = true
            } else {
                let config = TranslationEngine.Configuration(
                    targetLanguage: TranslationLanguage.chineseSimplified,
                    timeout: 10.0,
                    autoDetectSourceLanguage: true
                )
                let result = try await TranslationEngine.shared.translate(testText, config: config)

                translationTestResult = String(
                    format: NSLocalizedString("onboarding.test.success", comment: ""),
                    testText,
                    result.translatedText
                )
                translationTestSuccess = true
            }
        } catch {
            translationTestResult = String(
                format: NSLocalizedString("onboarding.test.failed", comment: ""),
                error.localizedDescription
            )
            translationTestSuccess = false
        }

        isTestingTranslation = false
    }

    private func completeOnboarding() {
        if !paddleOCRServerAddress.isEmpty {
            settings.paddleOCRServerAddress = paddleOCRServerAddress
        }

        if let (host, port) = parseServerURL(mtranServerURL), !host.isEmpty {
            settings.mtranServerHost = host
            settings.mtranServerPort = port
        }

        settings.onboardingCompleted = true
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }

    private func parseServerURL(_ url: String) -> (host: String, port: Int)? {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let colonIndex = trimmed.lastIndex(of: ":") {
            let host = String(trimmed[..<colonIndex])
            let portString = String(trimmed[colonIndex...].dropFirst())
            if let port = Int(portString) {
                return (host, port)
            }
        }

        return (trimmed, 8989)
    }

    func skipConfiguration() {
        paddleOCRServerAddress = ""
        mtranServerURL = ""
        completeOnboarding()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when onboarding is completed
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
