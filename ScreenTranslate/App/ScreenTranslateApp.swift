import SwiftUI

/// Main entry point for the ScreenTranslate application.
/// Uses SwiftUI App lifecycle with NSApplicationDelegate for menu bar integration.
@main
struct ScreenTranslateApp: App {
    /// AppDelegate for handling menu bar setup and hotkey registration
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene - we use AppSettings for preferences
        // The actual settings UI will be added in Phase 8 (US6)
        Settings {
            EmptyView()
        }
    }
}
