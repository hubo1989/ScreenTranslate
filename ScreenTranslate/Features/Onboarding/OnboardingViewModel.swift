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

    /// Type of permission being requested
    enum PermissionType {
        case screenRecording
        case accessibility
    }

    /// PaddleOCR server address
    var paddleOCRServerAddress = ""

    var mtranServerURL = "localhost:8989" {
        didSet {
            // Clear test result when URL changes
            translationTestResult = nil
            translationTestSuccess = false
        }
    }

    /// Whether a translation test is in progress
    var isTestingTranslation = false

    /// Translation test result message
    var translationTestResult: String?

    /// Translation test success status
    var translationTestSuccess = false

    /// Whether PaddleOCR is installed
    var isPaddleOCRInstalled = false

    /// Whether PaddleOCR installation is in progress
    var isInstallingPaddleOCR = false

    /// PaddleOCR installation error message
    var paddleOCRInstallError: String?

    /// PaddleOCR version if installed
    var paddleOCRVersion: String?

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
                // Only check accessibility permission on init (no system dialog)
                hasAccessibilityPermission = AccessibilityPermissionChecker.hasPermission
                // Don't auto-check screen recording - it may trigger system dialog
                refreshPaddleOCRStatus()
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
        // Check permissions when entering the permissions step
        if currentStep == 1 {
            checkPermissions()
        }
    }

    /// Moves to the previous step
    func goToPreviousStep() {
        guard canGoPrevious else { return }
        currentStep -= 1
        // Check permissions when entering the permissions step
        if currentStep == 1 {
            checkPermissions()
        }
    }

    /// Checks all permission statuses
    func checkPermissions() {
        hasAccessibilityPermission = AccessibilityPermissionChecker.hasPermission

        // Check screen recording (uses SCShareableContent for reliable check)
        Task {
            let granted = await ScreenDetector.shared.hasPermission()
            hasScreenRecordingPermission = granted
        }
    }

    /// Requests screen recording permission - opens System Settings
    func requestScreenRecordingPermission() {
        Task {
            // Check current status first
            let currentStatus = await ScreenDetector.shared.hasPermission()

            if currentStatus {
                hasScreenRecordingPermission = true
                return
            }

            // Open System Settings for screen recording
            openScreenRecordingSettings()
            // Start checking for permission
            startPermissionCheck(for: .screenRecording)
        }
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
                    let granted = await ScreenDetector.shared.hasPermission()
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
        }
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

        // Remove protocol if present
        var hostPart = trimmed
        if hostPart.hasPrefix("http://") {
            hostPart = String(hostPart.dropFirst(7))
        } else if hostPart.hasPrefix("https://") {
            hostPart = String(hostPart.dropFirst(8))
        }

        // Split by colon for port
        if let colonIndex = hostPart.firstIndex(of: ":") {
            let host = String(hostPart[..<colonIndex])
            let portAndPath = String(hostPart[hostPart.index(after: colonIndex)...])
            // Extract only the port number (stop at first non-digit or path separator)
            let portString = portAndPath.prefix { $0.isNumber }
            let port = Int(portString) ?? 8989
            return (host.isEmpty ? "localhost" : host, port)
        } else {
            return (hostPart.isEmpty ? "localhost" : hostPart, 8989)
        }
    }

    func skipConfiguration() {
        paddleOCRServerAddress = ""
        mtranServerURL = ""
        completeOnboarding()
    }

    // MARK: - PaddleOCR Management

    func refreshPaddleOCRStatus() {
        PaddleOCRChecker.resetCache()
        PaddleOCRChecker.checkAvailabilityAsync()
        
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(250))
                if PaddleOCRChecker.checkCompleted {
                    break
                }
            }
            await MainActor.run {
                isPaddleOCRInstalled = PaddleOCRChecker.isAvailable
                paddleOCRVersion = PaddleOCRChecker.version
                paddleOCRInstallError = nil
            }
        }
    }

    func installPaddleOCR() {
        isInstallingPaddleOCR = true
        paddleOCRInstallError = nil

        Task.detached(priority: .userInitiated) {
            let result = await self.runPipInstall()
            await MainActor.run {
                self.isInstallingPaddleOCR = false
                if let error = result {
                    self.paddleOCRInstallError = error
                } else {
                    self.refreshPaddleOCRStatus()
                }
            }
        }
    }

    private func runPipInstall() async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["pip3", "install", "paddleocr", "paddlepaddle"]

        let stderrPipe = Pipe()
        task.standardError = stderrPipe
        task.standardOutput = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                return stderr.isEmpty ? "Installation failed with exit code \(task.terminationStatus)" : stderr
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func copyInstallCommand() {
        let command = "pip3 install paddleocr paddlepaddle"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when onboarding is completed
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
