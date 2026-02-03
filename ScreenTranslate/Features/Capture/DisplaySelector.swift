import AppKit
import Foundation

/// Manages display selection UI when multiple displays are connected.
/// Provides a popup menu for the user to select which display to capture.
final class DisplaySelector: NSObject, NSMenuDelegate {
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

    /// Currently available displays (stored for lookup by tag)
    private var currentDisplays: [DisplayInfo] = []

    /// The display that was selected (set when menu item is clicked)
    private var selectedDisplay: DisplayInfo?

    // MARK: - Public API

    /// Shows a display selection menu if multiple displays are available.
    /// - Parameter displays: Array of available displays
    /// - Returns: The selected display or nil if cancelled
    @MainActor
    func selectDisplay(from displays: [DisplayInfo]) async -> DisplayInfo? {
        // If only one display, return it immediately
        guard displays.count > 1 else {
            return displays.first
        }

        // Store displays for lookup
        currentDisplays = displays
        selectedDisplay = nil

        // Show selection menu and wait for result
        let result = await withCheckedContinuation { continuation in
            self.selectionContinuation = continuation
            self.showSelectionMenu(for: displays)
        }

        // Clear stored displays
        currentDisplays = []

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
        menu.delegate = self

        // Add header item (disabled, for context)
        let headerItem = NSMenuItem(
            title: NSLocalizedString("display.selector.header", comment: "Choose display to capture:"),
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Add display items with tags for identification
        for (index, display) in displays.enumerated() {
            let item = NSMenuItem(
                title: display.name,
                action: #selector(displayItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index

            // Add resolution info via attributed title
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

            item.attributedTitle = attributedTitle

            // Add display icon
            if let icon = NSImage(systemSymbolName: "display", accessibilityDescription: nil) {
                icon.isTemplate = true
                item.image = icon
            }

            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Add cancel option
        let cancelItem = NSMenuItem(
            title: NSLocalizedString("display.selector.cancel", comment: "Cancel"),
            action: #selector(cancelItemClicked(_:)),
            keyEquivalent: "\u{1B}" // Escape key
        )
        cancelItem.target = self
        cancelItem.tag = -1
        menu.addItem(cancelItem)

        selectionMenu = menu

        // Show menu at mouse location on the main screen
        if let screen = NSScreen.main {
            let mouseLocation = NSEvent.mouseLocation
            // Convert to screen coordinates for the menu
            menu.popUp(positioning: nil, at: mouseLocation, in: nil)
        }
    }

    /// Called when a display item is clicked
    @objc func displayItemClicked(_ sender: NSMenuItem) {
        let index = sender.tag
        if index >= 0 && index < currentDisplays.count {
            selectedDisplay = currentDisplays[index]
            #if DEBUG
            print("Display item clicked: \(selectedDisplay?.name ?? "nil")")
            #endif
        }
    }

    /// Called when cancel item is clicked
    @objc func cancelItemClicked(_ sender: NSMenuItem) {
        selectedDisplay = nil
        #if DEBUG
        print("Cancel item clicked")
        #endif
    }

    // MARK: - NSMenuDelegate

    func menuDidClose(_ menu: NSMenu) {
        // The action fires AFTER menuDidClose, so we need to delay completion
        // to give the action a chance to set selectedDisplay
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            #if DEBUG
            print("Menu did close (delayed), selectedDisplay: \(self.selectedDisplay?.name ?? "nil")")
            #endif

            // Complete the selection based on what was selected
            if let display = self.selectedDisplay {
                self.completeSelection(with: .selected(display))
            } else {
                self.completeSelection(with: .cancelled)
            }
        }
    }

    /// Completes the selection with the given result.
    private func completeSelection(with result: SelectionResult) {
        selectionMenu?.delegate = nil
        selectionMenu = nil
        selectedDisplay = nil
        selectionContinuation?.resume(returning: result)
        selectionContinuation = nil
    }
}
