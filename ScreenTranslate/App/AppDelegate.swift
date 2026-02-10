import AppKit
import os

/// Application delegate responsible for menu bar setup, hotkey registration, and app lifecycle.
/// Runs on the main actor to ensure thread-safe UI operations.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var fullScreenHotkeyRegistration: HotkeyManager.Registration?
    private var selectionHotkeyRegistration: HotkeyManager.Registration?
    private var translationModeHotkeyRegistration: HotkeyManager.Registration?
    private let settings = AppSettings.shared
    private let displaySelector = DisplaySelector()
    private var isCaptureInProgress = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we're a menu bar only app (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Set up menu bar
        menuBarController = MenuBarController(appDelegate: self)
        menuBarController?.setup()

        // Register global hotkeys
        Task {
            await registerHotkeys()
        }

        // Show onboarding for first launch, otherwise check screen recording permission
        Task {
            await checkFirstLaunchAndShowOnboarding()
        }

        // Check PaddleOCR availability in background (non-blocking)
        PaddleOCRChecker.checkAvailabilityAsync()

        Logger.general.info("ScreenTranslate launched - settings loaded from: \(self.settings.saveLocation.path)")
    }

    /// Checks if this is the first launch and shows onboarding if needed.
    private func checkFirstLaunchAndShowOnboarding() async {
        if !settings.onboardingCompleted {
            // Show onboarding for first-time users
            _ = await MainActor.run { [settings] in
                OnboardingWindowController.shared.showOnboarding(settings: settings)
            }
        } else {
            // Existing users: just check screen recording permission
            await checkAndRequestScreenRecordingPermission()
        }
    }

    /// Checks for screen recording permission and shows an explanatory prompt if needed.
    private func checkAndRequestScreenRecordingPermission() async {
        // Check if we already have permission
        let hasPermission = await CaptureManager.shared.hasPermission

        if !hasPermission {
            // Show an explanatory alert before triggering the system prompt
            await MainActor.run {
                showPermissionExplanationAlert()
            }
        }
    }

    /// Shows an alert explaining why screen recording permission is needed.
    private func showPermissionExplanationAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString(
            "permission.prompt.title",
            comment: "Screen Recording Permission Required"
        )
        alert.informativeText = NSLocalizedString("permission.prompt.message", comment: "")
        alert.addButton(withTitle: NSLocalizedString("permission.prompt.continue", comment: "Continue"))
        alert.addButton(withTitle: NSLocalizedString("permission.prompt.later", comment: "Later"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Trigger the system permission prompt by attempting a capture
            Task {
                _ = await CaptureManager.shared.requestPermission()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Unregister hotkeys
        Task {
            await unregisterHotkeys()
        }

        // Remove menu bar item
        menuBarController?.teardown()

        Logger.general.info("ScreenTranslate terminating")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // For menu bar apps, we don't need to do anything special on reopen
        // The menu bar icon is always visible
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // Enable secure state restoration
        return true
    }

    // MARK: - Hotkey Management

    /// Registers global hotkeys for capture actions
    private func registerHotkeys() async {
        let hotkeyManager = HotkeyManager.shared

        // Register full screen capture hotkey
        do {
            fullScreenHotkeyRegistration = try await hotkeyManager.register(
                shortcut: settings.fullScreenShortcut
            ) { [weak self] in
                Task { @MainActor in
                    self?.captureFullScreen()
                }
            }
            Logger.ui.info("Registered full screen hotkey: \(self.settings.fullScreenShortcut.displayString)")
        } catch {
            Logger.ui.error("Failed to register full screen hotkey: \(error.localizedDescription)")
        }

        // Register selection capture hotkey
        do {
            selectionHotkeyRegistration = try await hotkeyManager.register(
                shortcut: settings.selectionShortcut
            ) { [weak self] in
                Task { @MainActor in
                    self?.captureSelection()
                }
            }
            Logger.ui.info("Registered selection hotkey: \(self.settings.selectionShortcut.displayString)")
        } catch {
            Logger.ui.error("Failed to register selection hotkey: \(error.localizedDescription)")
        }

        // Register translation mode hotkey
        do {
            translationModeHotkeyRegistration = try await hotkeyManager.register(
                shortcut: settings.translationModeShortcut
            ) { [weak self] in
                Task { @MainActor in
                    self?.startTranslationMode()
                }
            }
            Logger.ui.info("Registered translation mode hotkey: \(self.settings.translationModeShortcut.displayString)")
        } catch {
            Logger.ui.error("Failed to register translation mode hotkey: \(error.localizedDescription)")
        }
    }

    /// Unregisters all global hotkeys
    private func unregisterHotkeys() async {
        let hotkeyManager = HotkeyManager.shared

        if let registration = fullScreenHotkeyRegistration {
            await hotkeyManager.unregister(registration)
            fullScreenHotkeyRegistration = nil
        }

        if let registration = selectionHotkeyRegistration {
            await hotkeyManager.unregister(registration)
            selectionHotkeyRegistration = nil
        }

        if let registration = translationModeHotkeyRegistration {
            await hotkeyManager.unregister(registration)
            translationModeHotkeyRegistration = nil
        }
    }

    /// Re-registers hotkeys after settings change
    func updateHotkeys() {
        Task {
            await unregisterHotkeys()
            await registerHotkeys()
        }
    }

    // MARK: - Capture Actions

    /// Triggers a full screen capture
    @objc func captureFullScreen() {
        // Prevent overlapping captures
        guard !isCaptureInProgress else {
            Logger.capture.debug("Capture already in progress, ignoring request")
            return
        }

        Logger.capture.info("Full screen capture triggered via hotkey or menu")

        isCaptureInProgress = true

        Task {
            defer { isCaptureInProgress = false }

            do {
                // Get available displays
                let displays = try await CaptureManager.shared.availableDisplays()

                // Select display (shows menu if multiple)
                guard let selectedDisplay = await displaySelector.selectDisplay(from: displays) else {
                    Logger.capture.debug("Display selection cancelled")
                    return
                }

                Logger.capture.info("Capturing display: \(selectedDisplay.name)")

                // Perform capture
                let screenshot = try await CaptureManager.shared.captureFullScreen(display: selectedDisplay)

                Logger.capture.info("Capture successful: \(screenshot.formattedDimensions)")

                // Show preview window
                PreviewWindowController.shared.showPreview(for: screenshot)

            } catch let error as ScreenTranslateError {
                showCaptureError(error)
            } catch {
                showCaptureError(.captureFailure(underlying: error))
            }
        }
    }

    /// Triggers a selection capture
    @objc func captureSelection() {
        // Prevent overlapping captures
        guard !isCaptureInProgress else {
            Logger.capture.debug("Capture already in progress, ignoring request")
            return
        }

        Logger.capture.info("Selection capture triggered via hotkey or menu")

        isCaptureInProgress = true

        Task {
            do {
                // Present the selection overlay on all displays
                let overlayController = SelectionOverlayController.shared

                // Set up callbacks before presenting
                overlayController.onSelectionComplete = { [weak self] rect, display in
                    Task { @MainActor in
                        await self?.handleSelectionComplete(rect: rect, display: display)
                    }
                }

                overlayController.onSelectionCancel = { [weak self] in
                    Task { @MainActor in
                        self?.handleSelectionCancel()
                    }
                }

                try await overlayController.presentOverlay()

            } catch {
                isCaptureInProgress = false
                Logger.capture.error("Failed to present selection overlay: \(error.localizedDescription)")
                showCaptureError(.captureFailure(underlying: error))
            }
        }
    }

    /// Handles successful selection completion
    private func handleSelectionComplete(rect: CGRect, display: DisplayInfo) async {
        defer { isCaptureInProgress = false }

        do {
            Logger.capture.info("Selection complete: \(Int(rect.width))×\(Int(rect.height)) on \(display.name)")

            // Capture the selected region
            let screenshot = try await CaptureManager.shared.captureRegion(rect, from: display)

            Logger.capture.info("Region capture successful: \(screenshot.formattedDimensions)")

            await MainActor.run {
                PreviewWindowController.shared.showPreview(for: screenshot)
            }

        } catch let error as ScreenTranslateError {
            showCaptureError(error)
        } catch {
            showCaptureError(.captureFailure(underlying: error))
        }
    }

    private func handleSelectionCancel() {
        isCaptureInProgress = false
        Logger.capture.debug("Selection cancelled by user")
    }

    /// Opens the settings window
    @objc func openSettings() {
        Logger.ui.debug("Opening settings window")

        SettingsWindowController.shared.showSettings(appDelegate: self)
    }

    /// Opens the translation history window
    @objc func openHistory() {
        Logger.ui.debug("Opening translation history window")

        HistoryWindowController.shared.showHistory()
    }

    /// Starts translation mode - presents region selection for translation
    @objc func startTranslationMode() {
        guard !isCaptureInProgress else {
            Logger.capture.debug("Capture already in progress, ignoring translation mode request")
            return
        }

        Logger.capture.info("Translation mode triggered via hotkey or menu")

        isCaptureInProgress = true

        Task {
            do {
                let overlayController = SelectionOverlayController.shared

                overlayController.onSelectionComplete = { [weak self] rect, display in
                    Task { @MainActor in
                        await self?.handleTranslationSelection(rect: rect, display: display)
                    }
                }

                overlayController.onSelectionCancel = { [weak self] in
                    Task { @MainActor in
                        self?.handleSelectionCancel()
                    }
                }

                try await overlayController.presentOverlay()

            } catch {
                isCaptureInProgress = false
                Logger.capture.error("Failed to present translation overlay: \(error.localizedDescription)")
                showCaptureError(.captureFailure(underlying: error))
            }
        }
    }

    /// Handles translation mode selection completion
    private func handleTranslationSelection(rect: CGRect, display: DisplayInfo) async {
        defer { isCaptureInProgress = false }

        do {
            Logger.capture.info("Translation selection: \(Int(rect.width))×\(Int(rect.height)) on \(display.name)")

            let screenshot = try await CaptureManager.shared.captureRegion(rect, from: display)

            Logger.capture.info("Translation capture successful: \(screenshot.formattedDimensions)")

            TranslationFlowController.shared.startTranslation(image: screenshot.image)

        } catch let error as ScreenTranslateError {
            showCaptureError(error)
        } catch {
            showCaptureError(.captureFailure(underlying: error))
        }
    }

    // MARK: - Error Handling

    /// Shows an error alert for capture failures
    private func showCaptureError(_ error: ScreenTranslateError) {
        Logger.general.error("Capture error: \(error.localizedDescription)")

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = error.errorDescription ?? NSLocalizedString("error.capture.failed", comment: "")
        alert.informativeText = error.recoverySuggestion ?? ""

        switch error {
        case .permissionDenied:
            let openSettingsTitle = NSLocalizedString(
                "error.permission.open.settings",
                comment: "Open System Settings"
            )
            alert.addButton(withTitle: openSettingsTitle)
            alert.addButton(withTitle: NSLocalizedString("error.dismiss", comment: "Dismiss"))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings > Privacy > Screen Recording
                let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }

        case .displayDisconnected:
            // Offer to retry capture on a different display
            alert.addButton(withTitle: NSLocalizedString(
                "error.retry.capture",
                comment: "Retry"
            ))
            alert.addButton(withTitle: NSLocalizedString("error.dismiss", comment: "Dismiss"))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Retry the capture on the remaining displays
                captureFullScreen()
            }

        case .diskFull, .invalidSaveLocation:
            // Offer to open settings to change save location
            alert.addButton(withTitle: NSLocalizedString("menu.settings", comment: "Settings..."))
            alert.addButton(withTitle: NSLocalizedString("error.dismiss", comment: "Dismiss"))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openSettings()
            }

        default:
            alert.addButton(withTitle: NSLocalizedString("error.ok", comment: "OK"))
            alert.runModal()
        }
    }
}
