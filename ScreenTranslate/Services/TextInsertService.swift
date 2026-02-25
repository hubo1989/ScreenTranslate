//
//  TextInsertService.swift
//  ScreenTranslate
//
//  Created for US-005: Add copy and insert buttons to translation popup
//

import Foundation
import CoreGraphics
import ApplicationServices

/// Service for inserting text into the currently focused input field.
/// Uses CGEvent keyboard simulation to type text character by character.
actor TextInsertService {

    // MARK: - Types

    /// Errors that can occur during text insertion
    enum InsertError: LocalizedError, Sendable {
        /// Failed to create keyboard event
        case eventCreationFailed
        /// Accessibility permission is required but not granted
        case accessibilityPermissionDenied
        /// Text contains characters that cannot be typed
        case unsupportedCharacters(String)

        var errorDescription: String? {
            switch self {
            case .eventCreationFailed:
                return NSLocalizedString(
                    "error.text.insert.event.failed",
                    value: "Failed to create keyboard event",
                    comment: ""
                )
            case .accessibilityPermissionDenied:
                return NSLocalizedString(
                    "error.text.insert.accessibility.denied",
                    value: "Accessibility permission is required to insert text",
                    comment: ""
                )
            case .unsupportedCharacters(let chars):
                return NSLocalizedString(
                    "error.text.insert.unsupported.chars",
                    value: "Cannot type characters: \(chars)",
                    comment: ""
                )
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .eventCreationFailed:
                return NSLocalizedString(
                    "error.text.insert.event.failed.recovery",
                    value: "Please try again",
                    comment: ""
                )
            case .accessibilityPermissionDenied:
                return NSLocalizedString(
                    "error.text.insert.accessibility.denied.recovery",
                    value: "Grant accessibility permission in System Settings > Privacy & Security > Accessibility",
                    comment: ""
                )
            case .unsupportedCharacters:
                return NSLocalizedString(
                    "error.text.insert.unsupported.chars.recovery",
                    value: "Some characters cannot be typed with keyboard simulation",
                    comment: ""
                )
            }
        }
    }

    // MARK: - Properties

    /// Delay between keystrokes in seconds (for reliability)
    private let keystrokeDelay: TimeInterval

    // MARK: - Initialization

    init(keystrokeDelay: TimeInterval = 0.01) {
        self.keystrokeDelay = keystrokeDelay
    }

    // MARK: - Public API

    /// Inserts text into the currently focused input field by simulating keyboard input.
    /// - Parameter text: The text to insert
    /// - Throws: InsertError if the insertion fails
    func insertText(_ text: String) async throws {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw InsertError.accessibilityPermissionDenied
        }

        guard !text.isEmpty else { return }

        // Get the event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw InsertError.eventCreationFailed
        }

        // Type each character
        for character in text {
            try await typeCharacter(character, source: source)
            // Small delay between characters for reliability
            try await Task.sleep(nanoseconds: UInt64(keystrokeDelay * 1_000_000_000))
        }
    }

    /// Deletes the currently selected text and inserts new text via Unicode events.
    /// This bypasses the input method and inserts text directly.
    /// - Parameter text: The text to insert after deleting the selection
    /// - Throws: InsertError if the operation fails
    func deleteSelectionAndInsert(_ text: String) async throws {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw InsertError.accessibilityPermissionDenied
        }

        // Get the event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw InsertError.eventCreationFailed
        }

        // Step 1: Delete selected text by simulating Delete key
        try postDeleteKey(source: source)

        // Small delay after delete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Step 2: Insert text using Unicode events (bypasses input method)
        try await insertUnicodeText(text, source: source)
    }

    /// Inserts text using Unicode keyboard events, bypassing input methods
    private func insertUnicodeText(_ text: String, source: CGEventSource) async throws {
        // Process text in chunks that can be sent via keyboardSetUnicodeString
        // The maximum safe chunk is around 20 characters
        let chunkSize = 20
        let characters = Array(text)

        for i in stride(from: 0, to: characters.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, characters.count)
            let chunk = characters[i..<endIndex]
            let chunkText = String(chunk)

            // Convert to UTF-16 for keyboardSetUnicodeString
            let utf16Chars = Array(chunkText.utf16)

            guard let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0,
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0,
                keyDown: false
            ) else {
                throw InsertError.eventCreationFailed
            }

            var mutableChars = utf16Chars
            keyDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: &mutableChars)
            keyUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: &mutableChars)

            let loc = CGEventTapLocation.cghidEventTap
            keyDown.post(tap: loc)
            keyUp.post(tap: loc)

            // Small delay between chunks
            if i + chunkSize < characters.count {
                try await Task.sleep(nanoseconds: UInt64(keystrokeDelay * 1_000_000_000))
            }
        }
    }

    /// Posts a Delete key event to remove selected text
    private func postDeleteKey(source: CGEventSource) throws {
        // Delete key code is 51 on macOS
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: 51,
            keyDown: true
        ),
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: 51,
            keyDown: false
        ) else {
            throw InsertError.eventCreationFailed
        }

        let loc = CGEventTapLocation.cghidEventTap
        keyDown.post(tap: loc)
        keyUp.post(tap: loc)
    }

    /// Checks if text insertion is likely to work.
    /// Returns false if accessibility permission is not granted.
    var canInsert: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Private Helpers

    /// Types a single character using CGEvent.
    /// - Parameters:
    ///   - character: The character to type
    ///   - source: The CGEventSource to use
    /// - Throws: InsertError if typing fails
    private func typeCharacter(_ character: Character, source: CGEventSource) async throws {
        // Convert character to string
        let charString = String(character)

        // Get the UTF-16 code unit for the character
        guard let scalar = character.unicodeScalars.first else {
            // Skip characters we can't type
            return
        }

        // Create the keyboard events
        // For special characters, we need to use Unicode input
        let keyCode = keyCodeForCharacter(character)

        if keyCode != nil {
            // Use key code for ASCII characters
            try postKeyEvent(keyCode: keyCode!, source: source)
        } else {
            // Use Unicode input for non-ASCII characters
            try postUnicodeEvent(character: scalar, source: source)
        }
    }

    /// Posts a keyboard event for the given key code.
    /// - Parameters:
    ///   - keyCode: The key code to post
    ///   - source: The CGEventSource to use
    /// - Throws: InsertError if event creation fails
    private func postKeyEvent(keyCode: CGKeyCode, source: CGEventSource) throws {
        // Create key down event
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            throw InsertError.eventCreationFailed
        }

        // Create key up event
        guard let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            throw InsertError.eventCreationFailed
        }

        // Post events
        let loc = CGEventTapLocation.cghidEventTap
        keyDown.post(tap: loc)
        keyUp.post(tap: loc)
    }

    /// Posts a Unicode input event for non-ASCII characters.
    /// - Parameters:
    ///   - character: The Unicode scalar to type
    ///   - source: The CGEventSource to use
    /// - Throws: InsertError if event creation fails
    private func postUnicodeEvent(character: UnicodeScalar, source: CGEventSource) throws {
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0,
            keyDown: true
        ) else {
            throw InsertError.eventCreationFailed
        }

        // Handle surrogate pairs for characters outside BMP (e.g., emoji)
        let utf16 = String(character).utf16
        let count = utf16.count
        var chars = Array(utf16)

        keyDown.keyboardSetUnicodeString(stringLength: count, unicodeString: &chars)

        guard let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0,
            keyDown: false
        ) else {
            throw InsertError.eventCreationFailed
        }

        keyUp.keyboardSetUnicodeString(stringLength: count, unicodeString: &chars)

        let loc = CGEventTapLocation.cghidEventTap
        keyDown.post(tap: loc)
        keyUp.post(tap: loc)
    }

    /// Returns the key code for a given ASCII character, or nil for non-ASCII.
    ///
    /// This method provides key codes based on the US keyboard layout for ASCII characters.
    /// For non-ASCII characters (including international characters), the system falls back
    /// to Unicode input via `postUnicodeEvent`, which works correctly regardless of the
    /// current keyboard layout.
    ///
    /// - Parameter character: The character to get the key code for
    /// - Returns: The CGKeyCode for the character, or nil if not an ASCII character
    private func keyCodeForCharacter(_ character: Character) -> CGKeyCode? {
        // Map of ASCII characters to key codes
        // Based on macOS keyboard layout (US)
        // Note: Non-ASCII characters are handled via Unicode input in postUnicodeEvent
        switch character {
        case "a", "A": return 0
        case "s", "S": return 1
        case "d", "D": return 2
        case "f", "F": return 3
        case "h", "H": return 4
        case "g", "G": return 5
        case "z", "Z": return 6
        case "x", "X": return 7
        case "c", "C": return 8
        case "v", "V": return 9
        case "b", "B": return 11
        case "q", "Q": return 12
        case "w", "W": return 13
        case "e", "E": return 14
        case "r", "R": return 15
        case "y", "Y": return 16
        case "t", "T": return 17
        case "1", "!": return 18
        case "2", "@": return 19
        case "3", "#": return 20
        case "4", "$": return 21
        case "6", "^": return 22
        case "5", "%": return 23
        case "=", "+": return 24
        case "9", "(": return 25
        case "7", "&": return 26
        case "-", "_": return 27
        case "8", "*": return 28
        case "0", ")": return 29
        case "]", "}": return 30
        case "o", "O": return 31
        case "u", "U": return 32
        case "[", "{": return 33
        case "i", "I": return 34
        case "p", "P": return 35
        case "\n", "\r": return 36  // Return
        case "l", "L": return 37
        case "j", "J": return 38
        case "'", "\"": return 39
        case "k", "K": return 40
        case ";", ":": return 41
        case "\\", "|": return 42
        case ",", "<": return 43
        case "/", "?": return 44
        case "n", "N": return 45
        case "m", "M": return 46
        case ".", ">": return 47
        case " ", " ": return 49  // Space
        case "`", "~": return 50
        default: return nil
        }
    }
}

// MARK: - Shared Instance

extension TextInsertService {
    /// Shared instance for convenience
    static let shared = TextInsertService()
}
