import AppKit
import os
import UserNotifications

/// Application delegate responsible for menu bar setup, hotkey registration, and app lifecycle.
/// Runs on the main actor to ensure thread-safe UI operations.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var fullScreenHotkeyRegistration: HotkeyManager.Registration?
    private var selectionHotkeyRegistration: HotkeyManager.Registration?
    private var translationModeHotkeyRegistration: HotkeyManager.Registration?
    private var textSelectionTranslationHotkeyRegistration: HotkeyManager.Registration?
    private var translateAndInsertHotkeyRegistration: HotkeyManager.Registration?
    private let settings = AppSettings.shared
    private let displaySelector = DisplaySelector()
    private var isCaptureInProgress = false
    private var isTranslating = false

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

        // Register text selection translation hotkey
        do {
            textSelectionTranslationHotkeyRegistration = try await hotkeyManager.register(
                shortcut: settings.textSelectionTranslationShortcut
            ) { [weak self] in
                Task { @MainActor in
                    self?.translateSelectedText()
                }
            }
            Logger.ui.info("Registered text selection translation hotkey: \(self.settings.textSelectionTranslationShortcut.displayString)")
        } catch {
            Logger.ui.error("Failed to register text selection translation hotkey: \(error.localizedDescription)")
        }

        // Register translate and insert hotkey
        do {
            translateAndInsertHotkeyRegistration = try await hotkeyManager.register(
                shortcut: settings.translateAndInsertShortcut
            ) { [weak self] in
                Task { @MainActor in
                    self?.translateClipboardAndInsert()
                }
            }
            Logger.ui.info("Registered translate and insert hotkey: \(self.settings.translateAndInsertShortcut.displayString)")
        } catch {
            Logger.ui.error("Failed to register translate and insert hotkey: \(error.localizedDescription)")
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

        if let registration = textSelectionTranslationHotkeyRegistration {
            await hotkeyManager.unregister(registration)
            textSelectionTranslationHotkeyRegistration = nil
        }

        if let registration = translateAndInsertHotkeyRegistration {
            await hotkeyManager.unregister(registration)
            translateAndInsertHotkeyRegistration = nil
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

            TranslationFlowController.shared.startTranslation(
                image: screenshot.image,
                scaleFactor: screenshot.sourceDisplay.scaleFactor
            )

        } catch let error as ScreenTranslateError {
            showCaptureError(error)
        } catch {
            showCaptureError(.captureFailure(underlying: error))
        }
    }

    /// Translates currently selected text from any application
    @objc func translateSelectedText() {
        // Prevent concurrent translation operations
        guard !isTranslating else {
            Logger.ui.debug("Translation already in progress, ignoring request")
            return
        }

        Logger.ui.info("Text selection translation triggered via hotkey")

        isTranslating = true

        Task { [weak self] in
            defer { self?.isTranslating = false }

            await self?.handleTextSelectionTranslation()
        }
    }

    /// Translates clipboard content and inserts directly into focused input field
    @objc func translateClipboardAndInsert() {
        // Prevent concurrent translation operations
        guard !isTranslating else {
            Logger.ui.debug("Translation already in progress, ignoring request")
            return
        }

        Logger.ui.info("Translate and insert triggered via hotkey")

        isTranslating = true

        Task { [weak self] in
            defer { self?.isTranslating = false }

            await self?.handleTranslateClipboardAndInsert()
        }
    }

    /// Handles the complete text selection translation flow
    private func handleTextSelectionTranslation() async {
        // Check accessibility permission before attempting text capture
        let permissionManager = PermissionManager.shared
        permissionManager.refreshPermissionStatus()

        if !permissionManager.hasAccessibilityPermission {
            // Show permission request dialog
            let granted = await withCheckedContinuation { continuation in
                Task { @MainActor in
                    let result = permissionManager.requestAccessibilityPermission()
                    continuation.resume(returning: result)
                }
            }

            if !granted {
                // User declined or permission not granted - show error
                await MainActor.run {
                    permissionManager.showPermissionDeniedError(for: .accessibility)
                }
                return
            }
        }

        do {
            // Step 1: Capture selected text
            let textSelectionService = TextSelectionService.shared
            let selectionResult = try await textSelectionService.captureSelectedText()

            Logger.ui.info("Captured selected text: \(selectionResult.text.count) characters")
            Logger.ui.info("Source app: \(selectionResult.sourceApplication ?? "unknown")")

            // Step 2: Show loading indicator
            await showLoadingIndicator()

            // Step 3: Translate the captured text
            if #available(macOS 13.0, *) {
                let config = await TextTranslationConfig.fromAppSettings()
                let translationResult = try await TextTranslationFlow.shared.translate(
                    selectionResult.text,
                    config: config
                )

                Logger.ui.info("Translation completed in \(translationResult.processingTime * 1000)ms")

                // Step 4: Hide loading and display result popup
                await hideLoadingIndicator()

                await MainActor.run {
                    TextTranslationPopupController.shared.presentPopup(result: translationResult)
                }

            } else {
                await hideLoadingIndicator()
                showCaptureError(.captureFailure(underlying: NSError(
                    domain: "ScreenTranslate",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "macOS 13.0+ required for text translation"]
                )))
            }

        } catch let error as TextSelectionService.CaptureError {
            await hideLoadingIndicator()

            // Handle empty selection with user notification (no crash)
            switch error {
            case .noSelection:
                Logger.ui.info("No text selected for translation")
                await showNoSelectionNotification()
            case .accessibilityPermissionDenied:
                Logger.ui.error("Accessibility permission denied")
                showCaptureError(.captureFailure(underlying: error))
            default:
                Logger.ui.error("Failed to capture selected text: \(error.localizedDescription)")
                showCaptureError(.captureFailure(underlying: error))
            }

        } catch let error as TextTranslationError {
            await hideLoadingIndicator()
            Logger.ui.error("Translation failed: \(error.localizedDescription)")
            showCaptureError(.captureFailure(underlying: error))

        } catch {
            await hideLoadingIndicator()
            Logger.ui.error("Unexpected error during text translation: \(error.localizedDescription)")
            showCaptureError(.captureFailure(underlying: error))
        }
    }

    /// Shows a brief loading indicator for text translation
    private func showLoadingIndicator() async {
        await MainActor.run {
            // Use the existing loading window with a placeholder image
            // Create a small placeholder image for the loading state
            let placeholderImage = NSImage(
                systemSymbolName: "character.textbox",
                accessibilityDescription: "Translating"
            )

            // Create a simple loading window
            if let cgImage = placeholderImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                BilingualResultWindowController.shared.showLoading(
                    originalImage: cgImage,
                    scaleFactor: 2.0,
                    message: String(localized: "textTranslation.loading")
                )
            }
        }
    }

    /// Hides the loading indicator
    private func hideLoadingIndicator() async {
        await MainActor.run {
            BilingualResultWindowController.shared.close()
        }
    }

    /// Shows a notification when no text is selected
    private func showNoSelectionNotification() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = String(localized: "textTranslation.noSelection.title")
            alert.informativeText = String(localized: "textTranslation.noSelection.message")
            alert.addButton(withTitle: String(localized: "common.ok"))
            alert.runModal()
        }
    }

    /// Handles the translate clipboard and insert flow
    private func handleTranslateClipboardAndInsert() async {
        // Check accessibility permission before attempting text insertion
        let permissionManager = PermissionManager.shared
        permissionManager.refreshPermissionStatus()

        if !permissionManager.hasAccessibilityPermission {
            // Show permission request dialog
            let granted = await withCheckedContinuation { continuation in
                Task { @MainActor in
                    let result = permissionManager.requestAccessibilityPermission()
                    continuation.resume(returning: result)
                }
            }

            if !granted {
                // User declined or permission not granted - show error
                await MainActor.run {
                    permissionManager.showPermissionDeniedError(for: .accessibility)
                }
                return
            }
        }

        // Step 1: Get clipboard content
        let pasteboard = NSPasteboard.general
        guard let clipboardText = pasteboard.string(forType: .string),
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.ui.info("Clipboard is empty or contains no text")
            await showEmptyClipboardNotification()
            return
        }

        Logger.ui.info("Captured clipboard text: \(clipboardText.count) characters")

        // Step 2: Show brief loading indicator
        await showLoadingIndicator()

        // Step 3: Translate the clipboard text
        do {
            if #available(macOS 13.0, *) {
                let config = await TextTranslationConfig.fromAppSettings()
                let translationResult = try await TextTranslationFlow.shared.translate(
                    clipboardText,
                    config: config
                )

                Logger.ui.info("Translation completed in \(translationResult.processingTime * 1000)ms")

                // Step 4: Hide loading
                await hideLoadingIndicator()

                // Step 5: Insert translated text directly into focused input field
                let insertService = TextInsertService.shared
                try await insertService.insertText(translationResult.translatedText)

                Logger.ui.info("Translated text inserted successfully")

                // Step 6: Show success notification
                await showSuccessNotification()

            } else {
                await hideLoadingIndicator()
                showCaptureError(.captureFailure(underlying: NSError(
                    domain: "ScreenTranslate",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "macOS 13.0+ required for text translation"]
                )))
            }

        } catch let error as TextTranslationError {
            await hideLoadingIndicator()
            Logger.ui.error("Translation failed: \(error.localizedDescription)")
            showCaptureError(.captureFailure(underlying: error))

        } catch let error as TextInsertService.InsertError {
            await hideLoadingIndicator()
            Logger.ui.error("Text insertion failed: \(error.localizedDescription)")
            showCaptureError(.captureFailure(underlying: error))

        } catch {
            await hideLoadingIndicator()
            Logger.ui.error("Unexpected error during translate and insert: \(error.localizedDescription)")
            showCaptureError(.captureFailure(underlying: error))
        }
    }

    /// Shows a notification when clipboard is empty
    private func showEmptyClipboardNotification() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = String(localized: "translateAndInsert.emptyClipboard.title")
            alert.informativeText = String(localized: "translateAndInsert.emptyClipboard.message")
            alert.addButton(withTitle: String(localized: "common.ok"))
            alert.runModal()
        }
    }

    /// Shows a success notification after translate and insert
    private func showSuccessNotification() async {
        let center = UNUserNotificationCenter.current()
        // Request authorization if needed
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = String(localized: "translateAndInsert.success.title")
        content.body = String(localized: "translateAndInsert.success.message")
        content.sound = .default
        // Create trigger (immediate)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
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
