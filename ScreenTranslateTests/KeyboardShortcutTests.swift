import XCTest
@testable import ScreenTranslate

// MARK: - KeyboardShortcut Tests

/// Tests for KeyboardShortcut model
final class KeyboardShortcutTests: XCTestCase {

    // MARK: - Default Shortcuts

    func testFullScreenDefaultShortcut() {
        let shortcut = KeyboardShortcut.fullScreenDefault

        XCTAssertEqual(shortcut.keyCode, 0x14) // kVK_ANSI_3
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey | shiftKey))
        XCTAssertTrue(shortcut.isValid)
    }

    func testSelectionDefaultShortcut() {
        let shortcut = KeyboardShortcut.selectionDefault

        XCTAssertEqual(shortcut.keyCode, 0x15) // kVK_ANSI_4
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey | shiftKey))
        XCTAssertTrue(shortcut.isValid)
    }

    func testTranslationModeDefaultShortcut() {
        let shortcut = KeyboardShortcut.translationModeDefault

        XCTAssertEqual(shortcut.keyCode, 0x11) // kVK_ANSI_T
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey | shiftKey))
        XCTAssertTrue(shortcut.isValid)
    }

    // MARK: - Validation

    func testShortcutWithCommandModifierIsValid() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x00, // A
            modifiers: UInt32(cmdKey)
        )

        XCTAssertTrue(shortcut.isValid)
        XCTAssertTrue(shortcut.hasRequiredModifiers)
    }

    func testShortcutWithControlModifierIsValid() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x00, // A
            modifiers: UInt32(controlKey)
        )

        XCTAssertTrue(shortcut.isValid)
        XCTAssertTrue(shortcut.hasRequiredModifiers)
    }

    func testShortcutWithOptionModifierIsValid() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x00, // A
            modifiers: UInt32(optionKey)
        )

        XCTAssertTrue(shortcut.isValid)
        XCTAssertTrue(shortcut.hasRequiredModifiers)
    }

    func testShortcutWithNoModifierIsInvalid() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x00, // A
            modifiers: 0
        )

        XCTAssertFalse(shortcut.isValid)
        XCTAssertFalse(shortcut.hasRequiredModifiers)
    }

    func testShortcutWithOnlyShiftModifierIsInvalid() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x00, // A
            modifiers: UInt32(shiftKey)
        )

        XCTAssertFalse(shortcut.isValid)
        XCTAssertFalse(shortcut.hasRequiredModifiers)
    }

    // MARK: - Display String

    func testDisplayStringWithCommandShift() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x14, // 3
            modifiers: UInt32(cmdKey | shiftKey)
        )

        // Display string should contain modifiers and key
        let displayString = shortcut.displayString
        XCTAssertTrue(displayString.contains("Cmd"))
        XCTAssertTrue(displayString.contains("Shift"))
        XCTAssertTrue(displayString.contains("3"))
    }

    func testDisplayStringWithAllModifiers() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x00, // A
            modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey)
        )

        let displayString = shortcut.displayString
        XCTAssertTrue(displayString.contains("Ctrl"))
        XCTAssertTrue(displayString.contains("Opt"))
        XCTAssertTrue(displayString.contains("Shift"))
        XCTAssertTrue(displayString.contains("Cmd"))
        XCTAssertTrue(displayString.contains("A"))
    }

    // MARK: - Symbol String

    func testSymbolStringFormat() {
        let shortcut = KeyboardShortcut(
            keyCode: 0x14, // 3
            modifiers: UInt32(cmdKey | shiftKey)
        )

        let symbolString = shortcut.symbolString
        XCTAssertTrue(symbolString.contains("$"))  // shift
        XCTAssertTrue(symbolString.contains("@"))  // command
    }

    // MARK: - Modifier Conversion

    func testCarbonToNSEventModifierConversion() {
        let carbonModifiers = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        let shortcut = KeyboardShortcut(keyCode: 0x00, modifiers: carbonModifiers)

        let nsFlags = shortcut.nsModifierFlags

        XCTAssertTrue(nsFlags.contains(.command))
        XCTAssertTrue(nsFlags.contains(.shift))
        XCTAssertTrue(nsFlags.contains(.option))
        XCTAssertTrue(nsFlags.contains(.control))
    }

    func testNSEventToCarbonModifierConversion() {
        let nsFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let shortcut = KeyboardShortcut(keyCode: 0x00, modifierFlags: nsFlags)

        XCTAssertTrue(shortcut.modifiers & UInt32(cmdKey) != 0)
        XCTAssertTrue(shortcut.modifiers & UInt32(shiftKey) != 0)
        XCTAssertTrue(shortcut.modifiers & UInt32(optionKey) != 0)
        XCTAssertTrue(shortcut.modifiers & UInt32(controlKey) != 0)
    }

    // MARK: - Equatable

    func testShortcutEquality() {
        let shortcut1 = KeyboardShortcut(keyCode: 0x14, modifiers: UInt32(cmdKey | shiftKey))
        let shortcut2 = KeyboardShortcut(keyCode: 0x14, modifiers: UInt32(cmdKey | shiftKey))
        let shortcut3 = KeyboardShortcut(keyCode: 0x15, modifiers: UInt32(cmdKey | shiftKey))

        XCTAssertEqual(shortcut1, shortcut2)
        XCTAssertNotEqual(shortcut1, shortcut3)
    }

    // MARK: - Codable

    func testShortcutEncodingDecoding() throws {
        let original = KeyboardShortcut(keyCode: 0x14, modifiers: UInt32(cmdKey | shiftKey))

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KeyboardShortcut.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Main Key

    func testMainKeyForLetter() {
        let shortcut = KeyboardShortcut(keyCode: 0x00, modifiers: UInt32(cmdKey)) // A
        XCTAssertEqual(shortcut.mainKey, "A")
    }

    func testMainKeyForNumber() {
        let shortcut = KeyboardShortcut(keyCode: 0x14, modifiers: UInt32(cmdKey)) // 3
        XCTAssertEqual(shortcut.mainKey, "3")
    }

    func testMainKeyForFunctionKey() {
        let shortcut = KeyboardShortcut(keyCode: 0x7A, modifiers: UInt32(cmdKey)) // F1
        XCTAssertEqual(shortcut.mainKey, "F1")
    }
}
