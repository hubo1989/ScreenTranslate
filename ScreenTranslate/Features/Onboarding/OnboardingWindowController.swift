import AppKit
import SwiftUI

/// Controller for presenting and managing the first launch onboarding window.
/// Uses a singleton pattern to ensure only one onboarding window is shown.
@MainActor
final class OnboardingWindowController: NSObject {
    // MARK: - Singleton

    /// Shared instance
    static let shared = OnboardingWindowController()

    // MARK: - Properties

    /// The onboarding window
    private var window: NSWindow?

    /// Completion handler called when onboarding is completed or dismissed
    var completionHandler: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Presents the onboarding window if onboarding hasn't been completed.
    /// - Parameter settings: The app settings to check and update
    /// - Returns: Whether the onboarding window was shown
    @discardableResult
    func showOnboarding(settings: AppSettings = .shared) -> Bool {
        // Don't show if already completed
        guard !settings.onboardingCompleted else {
            completionHandler?()
            return false
        }

        // If window already exists, bring it to front
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return true
        }

        // Create view model
        let viewModel = OnboardingViewModel(settings: settings)

        // Create the SwiftUI view
        let onboardingView = OnboardingView(viewModel: viewModel)

        // Create the hosting view
        let hostingView = NSHostingView(rootView: onboardingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("onboarding.window.title", comment: "Welcome to ScreenTranslate")
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Set window level to floating to appear above other windows
        window.level = .floating

        // Prevent resizing
        window.isMovableByWindowBackground = false

        // Store reference
        self.window = window

        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        return true
    }

    /// Closes the onboarding window if open.
    func closeOnboarding() {
        window?.close()
        window = nil
    }
}

// MARK: - NSWindowDelegate

extension OnboardingWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Notify completion
            completionHandler?()

            // Clear references
            window = nil
        }
    }
}
