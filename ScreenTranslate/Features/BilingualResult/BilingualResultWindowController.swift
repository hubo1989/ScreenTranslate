import AppKit
import SwiftUI

@MainActor
final class BilingualResultWindowController: NSObject {
    static let shared = BilingualResultWindowController()

    private var window: NSWindow?
    private var viewModel: BilingualResultViewModel?

    private override init() {
        super.init()
    }

    func show(image: CGImage) {
        if let existingWindow = window, existingWindow.isVisible {
            viewModel?.updateImage(image)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newViewModel = BilingualResultViewModel(image: image)
        self.viewModel = newViewModel

        let contentView = BilingualResultView(viewModel: newViewModel)
        let hostingView = NSHostingView(rootView: contentView)

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let maxWidth: CGFloat = 1200
        let maxHeight: CGFloat = 800
        let minWidth: CGFloat = 400
        let minHeight: CGFloat = 300

        let scale = min(maxWidth / imageWidth, maxHeight / imageHeight, 1.0)
        let windowWidth = max(minWidth, imageWidth * scale)
        let windowHeight = max(minHeight, imageHeight * scale + 50)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.title = String(localized: "bilingualResult.windowTitle")
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.minSize = NSSize(width: minWidth, height: minHeight)
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

extension BilingualResultWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
        viewModel = nil
    }
}
