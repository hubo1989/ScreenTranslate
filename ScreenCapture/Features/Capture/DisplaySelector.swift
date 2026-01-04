import AppKit
import Foundation

/// Manages display selection UI when multiple displays are connected.
/// Provides a popup menu for the user to select which display to capture.
@MainActor
final class DisplaySelector {
    // MARK: - Types

    /// Result of display selection
    enum SelectionResult {
        case selected(DisplayInfo)
        case cancelled
    }

    // MARK: - Properties

    /// Completion handler for async selection
    private var selectionContinuation: CheckedContinuation<SelectionResult, Never>?

    /// Currently displayed menu
    private var selectionMenu: NSMenu?

    /// Menu delegate (retained to prevent deallocation)
    private var menuDelegate: DisplaySelectorMenuDelegate?

    // MARK: - Public API

    /// Shows a display selection menu if multiple displays are available.
    /// - Parameter displays: Array of available displays
    /// - Returns: The selected display or nil if cancelled
    func selectDisplay(from displays: [DisplayInfo]) async -> DisplayInfo? {
        // If only one display, return it immediately
        guard displays.count > 1 else {
            return displays.first
        }

        // Show selection menu and wait for result
        let result = await withCheckedContinuation { continuation in
            self.selectionContinuation = continuation
            self.showSelectionMenu(for: displays)
        }

        switch result {
        case .selected(let display):
            return display
        case .cancelled:
            return nil
        }
    }

    // MARK: - Private Methods

    /// Creates and shows the display selection menu.
    /// - Parameter displays: Available displays to choose from
    private func showSelectionMenu(for displays: [DisplayInfo]) {
        let menu = NSMenu(title: NSLocalizedString("display.selector.title", comment: "Select Display"))

        // Add header item (disabled, for context)
        let headerItem = NSMenuItem(
            title: NSLocalizedString("display.selector.header", comment: "Choose display to capture:"),
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Add display items
        for display in displays {
            let item = DisplayMenuItem(display: display)
            item.target = self
            item.action = #selector(displaySelected(_:))
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Add cancel option
        let cancelItem = NSMenuItem(
            title: NSLocalizedString("display.selector.cancel", comment: "Cancel"),
            action: #selector(selectionCancelled),
            keyEquivalent: "\u{1B}" // Escape key
        )
        cancelItem.target = self
        menu.addItem(cancelItem)

        // Set up menu delegate to handle dismissal
        menuDelegate = DisplaySelectorMenuDelegate(selector: self)
        menu.delegate = menuDelegate

        selectionMenu = menu

        // Show menu at current mouse location
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    /// Called when a display is selected from the menu.
    /// - Parameter sender: The selected menu item
    @objc private func displaySelected(_ sender: NSMenuItem) {
        guard let displayItem = sender as? DisplayMenuItem else { return }
        completeSelection(with: .selected(displayItem.display))
    }

    /// Called when selection is cancelled.
    @objc private func selectionCancelled() {
        completeSelection(with: .cancelled)
    }

    /// Called when the menu is dismissed without selection.
    fileprivate func menuDidClose() {
        // If continuation is still pending, treat as cancellation
        if selectionContinuation != nil {
            completeSelection(with: .cancelled)
        }
    }

    /// Completes the selection with the given result.
    /// - Parameter result: The selection result
    private func completeSelection(with result: SelectionResult) {
        selectionMenu = nil
        menuDelegate = nil
        selectionContinuation?.resume(returning: result)
        selectionContinuation = nil
    }
}

// MARK: - Display Menu Item

/// Custom menu item that holds a reference to a display.
private final class DisplayMenuItem: NSMenuItem {
    let display: DisplayInfo

    init(display: DisplayInfo) {
        self.display = display
        super.init(
            title: display.name,
            action: nil,
            keyEquivalent: ""
        )

        // Add resolution info
        let attributedTitle = NSMutableAttributedString(string: display.name)
        attributedTitle.append(NSAttributedString(
            string: "  \(display.resolution)",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            ]
        ))

        // Add primary indicator
        if display.isPrimary {
            attributedTitle.append(NSAttributedString(
                string: "  ★",
                attributes: [
                    .foregroundColor: NSColor.systemYellow,
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                ]
            ))
        }

        self.attributedTitle = attributedTitle

        // Add display icon
        if let icon = NSImage(systemSymbolName: "display", accessibilityDescription: nil) {
            icon.isTemplate = true
            self.image = icon
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Menu Delegate

/// Delegate to handle menu dismissal.
private final class DisplaySelectorMenuDelegate: NSObject, NSMenuDelegate {
    weak var selector: DisplaySelector?

    init(selector: DisplaySelector) {
        self.selector = selector
    }

    func menuDidClose(_ menu: NSMenu) {
        selector?.menuDidClose()
    }
}
