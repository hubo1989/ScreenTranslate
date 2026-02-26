//
//  TranslationScene.swift
//  ScreenTranslate
//
//  Translation scenarios for scene-based engine binding
//

import Foundation

/// Translation scene type for scene-based engine selection
enum TranslationScene: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Screenshot translation
    case screenshot = "screenshot"

    /// Text selection translation
    case textSelection = "text_selection"

    /// Translate and insert to clipboard
    case translateAndInsert = "translate_and_insert"

    var id: String { rawValue }

    /// Localized display name
    var localizedName: String {
        switch self {
        case .screenshot:
            return NSLocalizedString(
                "translation.scene.screenshot",
                comment: "Screenshot Translation"
            )
        case .textSelection:
            return NSLocalizedString(
                "translation.scene.text_selection",
                comment: "Text Selection Translation"
            )
        case .translateAndInsert:
            return NSLocalizedString(
                "translation.scene.translate_and_insert",
                comment: "Translate and Insert"
            )
        }
    }

    /// Scene description
    var sceneDescription: String {
        switch self {
        case .screenshot:
            return NSLocalizedString(
                "translation.scene.screenshot.description",
                comment: "OCR and translate captured screenshot regions"
            )
        case .textSelection:
            return NSLocalizedString(
                "translation.scene.text_selection.description",
                comment: "Translate selected text from any application"
            )
        case .translateAndInsert:
            return NSLocalizedString(
                "translation.scene.translate_and_insert.description",
                comment: "Translate clipboard text and insert at cursor"
            )
        }
    }

    /// Icon name for UI
    var iconName: String {
        switch self {
        case .screenshot:
            return "camera.viewfinder"
        case .textSelection:
            return "textformat"
        case .translateAndInsert:
            return "doc.on.clipboard"
        }
    }
}
