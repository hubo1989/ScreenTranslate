//
//  TextTranslationPopupWindow.swift
//  ScreenTranslate
//
//  Created for US-004: Create TextTranslationPopup window for showing translation results
//

import AppKit
import CoreGraphics
import SwiftUI

// MARK: - TextTranslationPopupDelegate

/// Delegate protocol for text translation popup events.
@MainActor
protocol TextTranslationPopupDelegate: AnyObject {
    /// Called when user dismisses the popup.
    func textTranslationPopupDidDismiss()
}

// MARK: - TextTranslationPopupWindow

/// NSPanel subclass for displaying text translation results in a popup near the mouse cursor.
/// Shows original text with source language label and translated text with target language label.
final class TextTranslationPopupWindow: NSPanel {
    // MARK: - Properties

    /// The original text that was translated
    private let originalText: String

    /// The translated text
    private let translatedText: String

    /// Source language display name
    private let sourceLanguage: String

    /// Target language display name
    private let targetLanguage: String

    /// The screen this popup appears on
    private let targetScreen: NSScreen

    /// The content view handling drawing and interaction
    private var popupView: TextTranslationPopupView?

    /// Delegate for popup events
    weak var popupDelegate: TextTranslationPopupDelegate?

    /// Monitor for global mouse events (click outside detection)
    private var eventMonitor: Any?

    /// Monitor for keyboard events (Escape key, Cmd+C, Enter)
    private var keyboardMonitor: Any?

    // MARK: - Initialization

    /// Creates a new text translation popup window.
    /// - Parameters:
    ///   - originalText: The original text that was translated
    ///   - translatedText: The translated text
    ///   - sourceLanguage: Source language display name
    ///   - targetLanguage: Target language display name
    ///   - screen: The NSScreen to display on
    @MainActor
    init(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        screen: NSScreen
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.targetScreen = screen

        // Initial frame - will be repositioned
        let initialFrame = CGRect(x: 0, y: 0, width: 400, height: 200)

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupPopupView()
        positionPopup()
    }

    deinit {
        // Note: removeEventMonitors is @MainActor, so we need to handle cleanup differently
        // The monitors will be cleaned up when dismissPopup is called
    }

    // MARK: - Configuration

    @MainActor
    private func configureWindow() {
        // Window properties for floating popup
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = true

        hidesOnDeactivate = true

        // Behavior
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false

        // Accept mouse events
        acceptsMouseMovedEvents = true
    }

    @MainActor
    private func setupPopupView() {
        let view = TextTranslationPopupView(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            window: self
        )
        self.contentView = view
        self.popupView = view
    }

    /// Positions the popup near the mouse cursor, respecting screen bounds
    @MainActor
    private func positionPopup() {
        guard let popupView = popupView else { return }

        // Calculate the size needed for the content
        let contentSize = popupView.sizeThatFits(NSSize(width: 380, height: 1000))

        // Get mouse location in screen coordinates
        let mouseLocation = NSEvent.mouseLocation

        // Position popup near mouse cursor with some padding
        let padding: CGFloat = 12

        // Default position: below and to the right of cursor
        var origin = CGPoint(
            x: mouseLocation.x + padding,
            y: mouseLocation.y - contentSize.height - padding
        )

        // Keep within screen bounds (horizontal)
        if origin.x + contentSize.width > targetScreen.frame.width - 20 {
            // Not enough space on right, try left
            origin.x = mouseLocation.x - contentSize.width - padding
        }

        if origin.x < 20 {
            origin.x = 20
        }

        // Keep within screen bounds (vertical)
        if origin.y < 20 {
            // Not enough space below, try above cursor
            origin.y = mouseLocation.y + padding
        }

        if origin.y + contentSize.height > targetScreen.frame.height - 20 {
            origin.y = targetScreen.frame.height - contentSize.height - 20
        }

        let newFrame = CGRect(origin: origin, size: contentSize)
        setFrame(newFrame, display: true)
    }

    // MARK: - Public API

    /// Shows the popup window
    @MainActor
    func showPopup() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        setupEventMonitors()
    }

    /// Dismisses the popup window
    @MainActor
    func dismissPopup() {
        removeEventMonitors()
        orderOut(nil)
        popupDelegate?.textTranslationPopupDidDismiss()
    }

    // MARK: - Event Monitors

    private func setupEventMonitors() {
        // Monitor for clicks outside the popup
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            // Check if click is outside the popup
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.contains(mouseLocation) {
                Task { @MainActor in
                    self.dismissPopup()
                }
            }
        }

        // Monitor for keyboard events (Escape, Cmd+C, Enter)
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Escape key dismisses popup
            if event.keyCode == 53 {
                Task { @MainActor in
                    self.dismissPopup()
                }
                return nil
            }

            // Enter key (with or without modifiers) inserts text and dismisses
            if event.keyCode == 36 { // kVK_Return
                Task { @MainActor in
                    self.handleInsertText(self.translatedText)
                }
                return nil
            }

            // Cmd+C copies translated text
            if event.keyCode == 8 && event.modifierFlags.contains(.command) { // kVK_ANSI_C + Cmd
                Task { @MainActor in
                    self.popupView?.performCopy()
                }
                return nil
            }

            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    // MARK: - NSWindow Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func resignKey() {
        super.resignKey()
        // Dismiss when losing focus (e.g., app switch)
        dismissPopup()
    }

    // MARK: - Text Insertion

    /// Handles the insert text action - types text into focused input and dismisses popup
    @MainActor
    func handleInsertText(_ text: String) {
        // Dismiss popup first to restore focus to original app
        dismissPopup()

        // Insert text using TextInsertService
        Task {
            do {
                try await TextInsertService.shared.insertText(text)
            } catch {
                // Log error but don't fail silently - could show a brief error
                print("Failed to insert text: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - TextTranslationPopupController

/// Controller for managing text translation popup lifecycle.
@MainActor
final class TextTranslationPopupController {
    // MARK: - Properties

    /// Shared instance
    static let shared = TextTranslationPopupController()

    /// The current popup window
    private var popupWindow: TextTranslationPopupWindow?

    /// Delegate for popup events
    weak var popupDelegate: TextTranslationPopupDelegate?

    /// Callback for when popup is dismissed
    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Presents text translation popup with the given translation result.
    /// - Parameters:
    ///   - result: The text translation result to display
    func presentPopup(result: TextTranslationResult) {
        // Dismiss any existing popup
        dismissPopup()

        guard let screen = NSScreen.main else { return }

        // Get display names for languages
        let sourceLanguageName = languageDisplayName(for: result.sourceLanguage)
        let targetLanguageName = languageDisplayName(for: result.targetLanguage)

        // Create popup window
        let popup = TextTranslationPopupWindow(
            originalText: result.originalText,
            translatedText: result.translatedText,
            sourceLanguage: sourceLanguageName,
            targetLanguage: targetLanguageName,
            screen: screen
        )
        popup.popupDelegate = self

        self.popupWindow = popup
        popup.showPopup()
    }

    /// Presents text translation popup with explicit text.
    /// - Parameters:
    ///   - originalText: The original text
    ///   - translatedText: The translated text
    ///   - sourceLanguage: Source language code
    ///   - targetLanguage: Target language code
    func presentPopup(
        originalText: String,
        translatedText: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) {
        // Dismiss any existing popup
        dismissPopup()

        guard let screen = NSScreen.main else { return }

        // Get display names for languages
        let sourceLanguageName = languageDisplayName(for: sourceLanguage)
        let targetLanguageName = languageDisplayName(for: targetLanguage)

        // Create popup window
        let popup = TextTranslationPopupWindow(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguageName,
            targetLanguage: targetLanguageName,
            screen: screen
        )
        popup.popupDelegate = self

        self.popupWindow = popup
        popup.showPopup()
    }

    /// Dismisses the current popup.
    func dismissPopup() {
        popupWindow?.dismissPopup()
        popupWindow = nil
        onDismiss?()
    }

    // MARK: - Private Helpers

    /// Returns a display name for a language code
    private func languageDisplayName(for code: String?) -> String {
        guard let code = code, !code.isEmpty else {
            return NSLocalizedString("language.auto", value: "Auto Detected", comment: "Auto detected language")
        }

        // Try to get localized language name using current locale
        let locale = Locale.current
        if let languageName = locale.localizedString(forLanguageCode: code) {
            return languageName
        }

        // Fallback to the code itself
        return code.uppercased()
    }
}

// MARK: - TextTranslationPopupController + TextTranslationPopupDelegate

extension TextTranslationPopupController: TextTranslationPopupDelegate {
    func textTranslationPopupDidDismiss() {
        popupWindow = nil
        onDismiss?()
        popupDelegate?.textTranslationPopupDidDismiss()
    }
}
