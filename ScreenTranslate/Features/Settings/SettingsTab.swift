import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, engines, languages, shortcuts, textTranslation, advanced
    var id: String { self.rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .general: return localized("settings.section.general")
        case .engines: return localized("settings.section.engines")
        case .languages: return localized("settings.section.languages")
        case .shortcuts: return localized("settings.section.shortcuts")
        case .textTranslation: return localized("settings.section.text.translation")
        case .advanced: return localized("settings.section.annotations")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .engines: return "engine.combustion"
        case .languages: return "globe"
        case .shortcuts: return "keyboard"
        case .textTranslation: return "text.bubble"
        case .advanced: return "pencil.tip.crop.circle"
        }
    }

    var color: Color {
        switch self {
        case .general: return .blue
        case .engines: return .orange
        case .languages: return .cyan
        case .shortcuts: return .purple
        case .textTranslation: return .pink
        case .advanced: return .green
        }
    }
}
