import Foundation
import SwiftUI

/// Styling for rectangle and freehand annotations.
struct StrokeStyle: Equatable, Codable, Sendable {
    /// Stroke color
    var color: CodableColor

    /// Stroke width in points (1.0...20.0)
    var lineWidth: CGFloat

    /// Default stroke style (red, 2pt)
    static let `default` = StrokeStyle(color: CodableColor(.red), lineWidth: 2.0)

    /// Validation: lineWidth must be between 1.0 and 20.0
    var isValid: Bool {
        (1.0...20.0).contains(lineWidth)
    }

    /// Returns a validated copy with lineWidth clamped to valid range
    var validated: StrokeStyle {
        StrokeStyle(
            color: color,
            lineWidth: min(max(lineWidth, 1.0), 20.0)
        )
    }
}

/// Styling for text annotations.
struct TextStyle: Equatable, Codable, Sendable {
    /// Text color
    var color: CodableColor

    /// Font size in points (8.0...72.0)
    var fontSize: CGFloat

    /// Font family name
    var fontName: String

    /// Default text style (red, 14pt, system font)
    static let `default` = TextStyle(
        color: CodableColor(.red),
        fontSize: 14.0,
        fontName: ".AppleSystemUIFont"
    )

    /// Validation: fontSize must be between 8.0 and 72.0
    var isValid: Bool {
        (8.0...72.0).contains(fontSize)
    }

    /// Returns a validated copy with fontSize clamped to valid range
    var validated: TextStyle {
        TextStyle(
            color: color,
            fontSize: min(max(fontSize, 8.0), 72.0),
            fontName: fontName
        )
    }

    /// The NSFont for this style
    @MainActor
    var nsFont: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }

    /// The SwiftUI Font for this style
    var font: Font {
        if fontName == ".AppleSystemUIFont" || fontName.isEmpty {
            return .system(size: fontSize)
        }
        return .custom(fontName, size: fontSize)
    }
}

// MARK: - CodableColor

/// A Codable wrapper for SwiftUI Color to enable persistence.
struct CodableColor: Equatable, Codable, Sendable {
    private var red: Double
    private var green: Double
    private var blue: Double
    private var opacity: Double

    init(_ color: Color) {
        // Convert Color to NSColor to extract components
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.red
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.opacity = Double(nsColor.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    /// The SwiftUI Color representation
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    /// The NSColor representation
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: opacity)
    }

    /// The CGColor representation
    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: opacity)
    }

    // MARK: - Preset Colors

    static let red = CodableColor(.red)
    static let blue = CodableColor(.blue)
    static let green = CodableColor(.green)
    static let yellow = CodableColor(.yellow)
    static let orange = CodableColor(.orange)
    static let white = CodableColor(.white)
    static let black = CodableColor(.black)
}
