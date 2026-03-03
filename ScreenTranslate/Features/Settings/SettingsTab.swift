import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, engines, prompts, languages, shortcuts, advanced
    var id: String { self.rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .general: return localized("settings.section.general")
        case .engines: return localized("settings.section.engines")
        case .prompts: return localized("settings.section.prompts")
        case .languages: return localized("settings.section.languages")
        case .shortcuts: return localized("settings.section.shortcuts")
        case .advanced: return localized("settings.section.annotations")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .engines: return "engine.combustion"
        case .prompts: return "text.bubble"
        case .languages: return "globe"
        case .shortcuts: return "keyboard"
        case .advanced: return "pencil.tip.crop.circle"
        }
    }

    var color: Color {
        switch self {
        case .general: return .blue
        case .engines: return .orange
        case .prompts: return .pink
        case .languages: return .cyan
        case .shortcuts: return .purple
        case .advanced: return .green
        }
    }
}
