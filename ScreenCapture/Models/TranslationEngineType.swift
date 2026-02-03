import Foundation

/// Translation engine types supported by the application
enum TranslationEngineType: String, CaseIterable, Sendable, Codable {
    /// macOS native Translation API (local, default)
    case apple = "apple"

    /// MTranServer (optional, external)
    case mtranServer = "mtran"

    /// Localized display name
    var localizedName: String {
        switch self {
        case .apple:
            return NSLocalizedString("translation.engine.apple", comment: "Apple Translation (Local)")
        case .mtranServer:
            return NSLocalizedString("translation.engine.mtran", comment: "MTranServer")
        }
    }

    /// Description of the engine
    var description: String {
        switch self {
        case .apple:
            return NSLocalizedString(
                "translation.engine.apple.description",
                comment: "Built-in macOS translation, no setup required"
            )
        case .mtranServer:
            return NSLocalizedString(
                "translation.engine.mtran.description",
                comment: "Self-hosted translation server"
            )
        }
    }

    /// Whether this engine is available (local engines are always available)
    var isAvailable: Bool {
        switch self {
        case .apple:
            return true
        case .mtranServer:
            // MTranServer requires external setup
            return false
        }
    }
}
