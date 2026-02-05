import AppKit
import SwiftUI

/// NSPanel subclass for displaying the screenshot preview.
/// Floats above other windows and hosts SwiftUI content.
final class PreviewWindow: NSPanel {
    // MARK: - Properties

    /// The view model for this preview
    private let viewModel: PreviewViewModel

    /// The hosting view for SwiftUI content
    private var hostingView: NSHostingView<PreviewContentView>?

    // MARK: - Initialization

    /// Creates a new preview window for the given screenshot.
    /// - Parameters:
    ///   - screenshot: The screenshot to preview
    ///   - onDismiss: Callback when the window should close
    ///   - onSave: Callback when the screenshot is saved
    @MainActor
    init(
        screenshot: Screenshot,
        onDismiss: @escaping () -> Void,
        onSave: @escaping (URL) -> Void
    ) {
        // Create view model
        self.viewModel = PreviewViewModel(screenshot: screenshot)
        viewModel.onDismiss = onDismiss
        viewModel.onSave = onSave

        // Calculate initial window size based on image dimensions
        let imageSize = CGSize(width: screenshot.image.width, height: screenshot.image.height)
        let windowSize = Self.calculateWindowSize(for: imageSize)
        let contentRect = Self.calculateCenteredRect(size: windowSize)

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupHostingView()
    }

    // MARK: - Configuration

    /// Configures window properties
    @MainActor
    private func configureWindow() {
        // Window behavior
        title = NSLocalizedString("preview.window.title", comment: "Screenshot Preview")
        level = .floating
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        // Appearance
        backgroundColor = .windowBackgroundColor
        titlebarAppearsTransparent = false
        titleVisibility = .visible

        // Size constraints - minimum width accommodates toolbar UI
        minSize = NSSize(width: 700, height: 400)
        maxSize = NSSize(width: 4000, height: 3000)

        // Collection behavior for proper window management
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// Sets up the SwiftUI hosting view
    @MainActor
    private func setupHostingView() {
        let contentView = PreviewContentView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: contentView)
        hosting.autoresizingMask = [.width, .height]

        self.contentView = hosting
        self.hostingView = hosting

        // Start observing image size changes
        observeImageSizeChanges()
    }

    /// Observes changes to the image size and resizes the window accordingly
    @MainActor
    private func observeImageSizeChanges() {
        // Track the current counter value
        var lastCounter = viewModel.imageSizeChangeCounter

        // Use a timer to periodically check for changes (more reliable than withObservationTracking)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                let currentCounter = self.viewModel.imageSizeChangeCounter
                if currentCounter != lastCounter {
                    lastCounter = currentCounter
                    self.resizeToFitImage()
                }
            }
        }
    }

    /// Resizes the window to fit the current image
    @MainActor
    func resizeToFitImage() {
        let imageSize = CGSize(
            width: viewModel.screenshot.image.width,
            height: viewModel.screenshot.image.height
        )
        let newSize = Self.calculateWindowSize(for: imageSize)

        // Animate the window resize, keeping it centered
        let currentFrame = frame
        let newX = currentFrame.midX - newSize.width / 2
        let newY = currentFrame.midY - newSize.height / 2
        let newFrame = NSRect(x: newX, y: newY, width: newSize.width, height: newSize.height)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Window Sizing

    /// Calculates an appropriate window size for the given image dimensions.
    /// Scales down if the image is larger than the available screen space.
    /// - Parameter imageSize: The image dimensions
    /// - Returns: The calculated window size
    @MainActor
    private static func calculateWindowSize(for imageSize: CGSize) -> NSSize {
        guard let screen = NSScreen.main else {
            return NSSize(width: min(imageSize.width, 800), height: min(imageSize.height, 600))
        }

        let screenFrame = screen.visibleFrame

        // Leave some padding around the window
        let maxWidth = screenFrame.width * 0.8
        let maxHeight = screenFrame.height * 0.8

        // Calculate scale factor to fit within screen
        let widthScale = maxWidth / imageSize.width
        let heightScale = maxHeight / imageSize.height
        let scale = min(widthScale, heightScale, 1.0) // Don't scale up

        // Add some padding for the info bar and controls
        let windowWidth = imageSize.width * scale
        let windowHeight = imageSize.height * scale + 60 // Extra height for info bar

        // Minimum size must accommodate toolbar UI elements
        return NSSize(width: max(windowWidth, 700), height: max(windowHeight, 400))
    }

    /// Calculates a centered rect for the window.
    /// - Parameter size: The desired window size
    /// - Returns: The centered window frame
    @MainActor
    private static func calculateCenteredRect(size: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.midY - size.height / 2

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: - Keyboard Handling

    /// Handle key events for shortcuts
    override func keyDown(with event: NSEvent) {
        guard !handleSpecialKeys(event) else { return }
        super.keyDown(with: event)
    }

    private func handleSpecialKeys(_ event: NSEvent) -> Bool {
        if handleEscape(event) { return true }
        if handleDelete(event) { return true }
        if handleReturn(event) { return true }
        if handleCommandShortcuts(event) { return true }
        if handleToolShortcuts(event) { return true }
        return false
    }

    private func handleEscape(_ event: NSEvent) -> Bool {
        guard event.keyCode == 53 else { return false }
        Task { @MainActor in
            if viewModel.selectedAnnotationIndex != nil {
                viewModel.deselectAnnotation()
            } else if viewModel.selectedTool != nil {
                viewModel.selectTool(nil)
            } else {
                viewModel.dismiss()
            }
        }
        return true
    }

    private func handleDelete(_ event: NSEvent) -> Bool {
        guard event.keyCode == 51 || event.keyCode == 117 else { return false }
        Task { @MainActor in
            if viewModel.selectedAnnotationIndex != nil {
                viewModel.deleteSelectedAnnotation()
            }
        }
        return true
    }

    private func handleReturn(_ event: NSEvent) -> Bool {
        guard event.keyCode == 36 || event.keyCode == 76 else { return false }
        Task { @MainActor in
            if viewModel.isCropMode && viewModel.cropRect != nil {
                viewModel.applyCrop()
            } else {
                viewModel.saveScreenshot()
            }
        }
        return true
    }

    private func handleCommandShortcuts(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        let char = event.charactersIgnoringModifiers?.lowercased()

        switch char {
        case "s":
            Task { @MainActor in viewModel.saveScreenshot() }
            return true
        case "c":
            Task { @MainActor in
                viewModel.copyToClipboard()
                viewModel.dismiss()
            }
            return true
        case "z":
            if event.modifierFlags.contains(.shift) {
                Task { @MainActor in viewModel.redo() }
            } else {
                Task { @MainActor in viewModel.undo() }
            }
            return true
        default:
            return false
        }
    }

    private func handleToolShortcuts(_ event: NSEvent) -> Bool {
        guard let char = event.charactersIgnoringModifiers?.lowercased().first else { return false }

        if char == "c" && !event.modifierFlags.contains(.command) {
            Task { @MainActor in viewModel.toggleCropMode() }
            return true
        }

        switch char {
        case "r":
            Task { @MainActor in toggleTool(.rectangle) }
            return true
        case "d":
            Task { @MainActor in toggleTool(.freehand) }
            return true
        case "a":
            Task { @MainActor in toggleTool(.arrow) }
            return true
        case "t":
            Task { @MainActor in toggleTool(.text) }
            return true
        case "1", "2", "3", "4":
            if let digit = Int(String(char)) {
                let toolIndex = digit - 1
                let tools = AnnotationToolType.allCases
                if toolIndex < tools.count {
                    Task { @MainActor in toggleTool(tools[toolIndex]) }
                }
            }
            return true
        default:
            return false
        }
    }

    @MainActor
    private func toggleTool(_ tool: AnnotationToolType) {
        if viewModel.selectedTool == tool {
            viewModel.selectTool(nil)
        } else {
            viewModel.selectTool(tool)
        }
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    // MARK: - Public API

    /// Shows the preview window
    @MainActor
    func showPreview() {
        viewModel.show()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the preview window
    @MainActor
    func closePreview() {
        viewModel.hide()
        close()
    }
}

// MARK: - PreviewWindowController

/// Controller for managing preview window lifecycle.
@MainActor
final class PreviewWindowController: NSWindowController {
    // MARK: - Properties

    /// The current preview window
    private var previewWindow: PreviewWindow?

    /// Shared instance
    static let shared = PreviewWindowController()

    // MARK: - Initialization

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    /// Shows a preview window for the given screenshot.
    /// - Parameters:
    ///   - screenshot: The screenshot to preview
    ///   - onSave: Callback when the screenshot is saved
    func showPreview(
        for screenshot: Screenshot,
        onSave: @escaping (URL) -> Void = { _ in }
    ) {
        // Close any existing preview
        closePreview()

        // Create new preview window
        previewWindow = PreviewWindow(
            screenshot: screenshot,
            onDismiss: { [weak self] in
                self?.closePreview()
            },
            onSave: onSave
        )

        previewWindow?.showPreview()
    }

    /// Closes the current preview window
    func closePreview() {
        previewWindow?.closePreview()
        previewWindow = nil
    }
}
