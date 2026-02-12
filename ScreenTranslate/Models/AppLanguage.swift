import Foundation
import SwiftUI

/// Supported application display languages.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Follow system language (fallback to English if unsupported)
    case system = "system"
    /// English
    case english = "en"
    /// Simplified Chinese
    case simplifiedChinese = "zh-Hans"
    
    var id: String { rawValue }
    
    /// The display name for this language option
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "settings.language.system")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
    
    /// The locale identifier for this language
    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
    
    /// All supported language codes (excluding system)
    static var supportedLanguageCodes: [String] {
        allCases.compactMap { $0.localeIdentifier }
    }
}

/// Manages application language settings and provides runtime language switching.
@MainActor
@Observable
final class LanguageManager {
    // MARK: - Singleton
    
    static let shared = LanguageManager()
    
    // MARK: - Properties
    
    /// The currently selected language
    var currentLanguage: AppLanguage {
        didSet {
            if oldValue != currentLanguage {
                applyLanguage()
                saveLanguage()
            }
        }
    }
    
    /// The active bundle for localized strings
    private(set) var bundle: Bundle = .main
    
    /// Notification name for language change
    static let languageDidChangeNotification = Notification.Name("LanguageDidChange")
    
    // MARK: - UserDefaults Key
    
    private let languageKey = "ScreenTranslate.appLanguage"
    
    // MARK: - Initialization
    
    private init() {
        // Load saved language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
        
        applyLanguage()
    }
    
    // MARK: - Public Methods
    
    /// Returns a localized string for the given key
    func localizedString(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: bundle, comment: comment)
    }
    
    /// Returns the effective locale identifier (resolves system to actual language)
    var effectiveLocaleIdentifier: String {
        if let localeId = currentLanguage.localeIdentifier {
            return localeId
        }
        
        // For system, detect the preferred language
        let preferredLanguages = Locale.preferredLanguages
        for preferred in preferredLanguages {
            // Check if we support this language
            if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh_Hans") || preferred == "zh-CN" {
                return "zh-Hans"
            }
            if preferred.hasPrefix("en") {
                return "en"
            }
        }
        
        // Default to English
        return "en"
    }
    
    // MARK: - Private Methods
    
    private func applyLanguage() {
        let localeId = effectiveLocaleIdentifier
        
        // Find the bundle for this language
        if let path = Bundle.main.path(forResource: localeId, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            bundle = languageBundle
        } else {
            // Fallback to main bundle (English)
            bundle = .main
        }
        
        // Apply to UserDefaults for system-level settings
        UserDefaults.standard.set([localeId], forKey: "AppleLanguages")
        
        // Post notification for views to refresh
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
    }
    
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }
}

// MARK: - String Extension for Localization

extension String {
    /// Returns a localized version of this string using the current app language
    @MainActor
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }
    
    /// Returns a localized string with format arguments
    @MainActor
    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}

// MARK: - SwiftUI LocalizedText View

/// A Text view that automatically updates when app language changes
struct LocalizedText: View {
    private let key: String
    @State private var refreshID = UUID()
    
    init(_ key: String) {
        self.key = key
    }
    
    var body: some View {
        Text(LanguageManager.shared.localizedString(key))
            .id(refreshID)
            .onReceive(NotificationCenter.default.publisher(for: LanguageManager.languageDidChangeNotification)) { _ in
                refreshID = UUID()
            }
    }
}

// MARK: - Localized String Helper Function

/// Returns a localized string using the current app language bundle
@MainActor
func localized(_ key: String) -> String {
    LanguageManager.shared.localizedString(key)
}
