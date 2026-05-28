import CoreGraphics
import Foundation
import SwiftUI

// MARK: - BilingualSegment

/// Represents a text segment with both original and translated content.
/// Used for bilingual overlay rendering.
struct BilingualSegment: Sendable, Equatable, Identifiable {
    let id: UUID
    let original: TextSegment
    let translated: String
    let sourceLanguage: String?
    let targetLanguage: String

    init(
        id: UUID = UUID(),
        original: TextSegment,
        translated: String,
        sourceLanguage: String? = nil,
        targetLanguage: String
    ) {
        self.id = id
        self.original = original
        self.translated = translated
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    /// Convenience initializer from TranslationResult (creates a TextSegment with empty bounding box)
    init(from result: TranslationResult) {
        self.id = UUID()
        self.original = TextSegment(
            text: result.sourceText,
            boundingBox: .zero,
            confidence: 1.0
        )
        self.translated = result.translatedText
        self.sourceLanguage = result.sourceLanguage
        self.targetLanguage = result.targetLanguage
    }

    /// Convenience initializer pairing a TextSegment with its translation
    init(segment: TextSegment, translatedText: String, sourceLanguage: String? = nil, targetLanguage: String) {
        self.id = segment.id
        self.original = segment
        self.translated = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

// MARK: - BilingualSegment Utilities

extension BilingualSegment {
    /// The original text content
    var sourceText: String {
        original.text
    }

    /// The bounding box of the original text (normalized coordinates)
    var boundingBox: CGRect {
        original.boundingBox
    }

    /// Returns the pixel bounding box for the original text
    func pixelBoundingBox(in imageSize: CGSize) -> CGRect {
        original.pixelBoundingBox(in: imageSize)
    }
}

// MARK: - OverlayStyle

/// Styling configuration for translation overlay rendering.
/// Controls how translated text appears over the original content.
struct OverlayStyle: Sendable, Equatable, Codable {
    /// Font for displaying translated text
    var translationFont: TranslationFont

    /// Color of the translated text
    var translationColor: CodableColor

    /// Background color behind the translated text (supports transparency)
    var backgroundColor: CodableColor

    /// Padding around the translated text in points
    var padding: EdgePadding

    /// Default overlay style with readable defaults
    static let `default` = OverlayStyle(
        translationFont: .default,
        translationColor: CodableColor(.white),
        backgroundColor: CodableColor(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.75),
        padding: .default
    )

    /// Dark mode optimized style
    static let dark = OverlayStyle(
        translationFont: .default,
        translationColor: CodableColor(.white),
        backgroundColor: CodableColor(red: 0.1, green: 0.1, blue: 0.1, opacity: 0.85),
        padding: .default
    )

    /// Minimal style with transparent background
    static let minimal = OverlayStyle(
        translationFont: TranslationFont(size: 12, weight: .regular),
        translationColor: CodableColor(.black),
        backgroundColor: CodableColor(red: 0, green: 0, blue: 0, opacity: 0),
        padding: EdgePadding(top: 2, leading: 4, bottom: 2, trailing: 4)
    )
}

// MARK: - TranslationFont

/// Font configuration for translation overlay text
struct TranslationFont: Sendable, Equatable, Codable {
    /// Font size in points (8.0...48.0)
    var size: CGFloat

    /// Font weight
    var weight: FontWeight

    /// Optional custom font family name (nil uses system font)
    var fontName: String?

    /// Default translation font (14pt, medium weight, system font)
    static let `default` = TranslationFont(size: 14, weight: .medium)

    init(size: CGFloat, weight: FontWeight = .regular, fontName: String? = nil) {
        self.size = min(max(size, 8.0), 48.0)
        self.weight = weight
        self.fontName = fontName
    }

    /// The SwiftUI Font representation
    var font: Font {
        if let fontName = fontName, !fontName.isEmpty {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight.swiftUIWeight)
    }

    /// The NSFont representation (non-isolated for use in rendering context)
    func makeNSFont() -> NSFont {
        if let fontName = fontName, let font = NSFont(name: fontName, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: weight.nsWeight)
    }
}

// MARK: - FontWeight

/// Font weight options for translation text
enum FontWeight: String, Sendable, Codable, CaseIterable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    var nsWeight: NSFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

// MARK: - EdgePadding

/// Padding configuration for overlay content
struct EdgePadding: Sendable, Equatable, Codable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    /// Default padding (4pt vertical, 8pt horizontal)
    static let `default` = EdgePadding(top: 4, leading: 8, bottom: 4, trailing: 8)

    /// Zero padding
    static let zero = EdgePadding(top: 0, leading: 0, bottom: 0, trailing: 0)

    /// Uniform padding on all sides
    init(all: CGFloat) {
        self.top = all
        self.leading = all
        self.bottom = all
        self.trailing = all
    }

    /// Custom padding per edge
    init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// Horizontal + vertical padding
    init(horizontal: CGFloat, vertical: CGFloat) {
        self.top = vertical
        self.leading = horizontal
        self.bottom = vertical
        self.trailing = horizontal
    }

    /// SwiftUI EdgeInsets representation
    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }

    /// Total horizontal padding
    var horizontal: CGFloat {
        leading + trailing
    }

    /// Total vertical padding
    var vertical: CGFloat {
        top + bottom
    }
}
