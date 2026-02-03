import Foundation

/// Translation display mode options
enum TranslationMode: String, CaseIterable, Sendable, Codable {
    /// Overlay translation at the exact position of original text
    case inline

    /// Show translation in a popover below the selected area
    case below

    /// Localized display name
    var localizedName: String {
        switch self {
        case .inline:
            return NSLocalizedString(
                "translation.mode.inline",
                comment: "In-place Replacement"
            )
        case .below:
            return NSLocalizedString(
                "translation.mode.below",
                comment: "Below Original"
            )
        }
    }

    /// Description of the mode
    var description: String {
        switch self {
        case .inline:
            return NSLocalizedString(
                "translation.mode.inline.description",
                comment: "Replace original text with translation"
            )
        case .below:
            return NSLocalizedString(
                "translation.mode.below.description",
                comment: "Show translation in a floating window"
            )
        }
    }
}
