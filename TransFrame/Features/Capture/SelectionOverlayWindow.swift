import AppKit
import CoreGraphics
import os

// MARK: - SelectionOverlayDelegate

/// Delegate protocol for selection overlay events.
@MainActor
protocol SelectionOverlayDelegate: AnyObject {
    /// Called when user completes a selection.
    /// - Parameters:
    ///   - rect: The selected rectangle in screen coordinates
    ///   - display: The display containing the selection
    func selectionOverlay(didSelectRect rect: CGRect, on display: DisplayInfo)

    /// Called when user cancels the selection.
    func selectionOverlayDidCancel()
}

// MARK: - SelectionOverlayWindow

/// NSPanel subclass for displaying the selection overlay.
/// Provides a full-screen transparent overlay with crosshair cursor,
/// dim effect, and selection rectangle drawing.
final class SelectionOverlayWindow: NSPanel {
    // MARK: - Properties

    /// The screen this overlay covers
    let targetScreen: NSScreen

    /// The display info for this screen
    let displayInfo: DisplayInfo

    /// The content view handling drawing and interaction
    private var overlayView: SelectionOverlayView?

    // MARK: - Initialization

    /// Creates a new selection overlay window for the specified screen.
    /// - Parameters:
    ///   - screen: The NSScreen to overlay
    ///   - displayInfo: The DisplayInfo for the screen
    @MainActor
    init(screen: NSScreen, displayInfo: DisplayInfo) {
        self.targetScreen = screen
        self.displayInfo = displayInfo

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupOverlayView()
    }

    // MARK: - Configuration

    @MainActor
    private func configureWindow() {
        // Window properties for full-screen overlay
        level = .screenSaver // Above most windows but below alerts
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false

        // Don't hide on deactivation
        hidesOnDeactivate = false

        // Behavior
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false

        // Accept mouse events
        acceptsMouseMovedEvents = true
    }

    @MainActor
    private func setupOverlayView() {
        let view = SelectionOverlayView(frame: targetScreen.frame)
        view.autoresizingMask = [.width, .height]
        self.contentView = view
        self.overlayView = view
    }

    // MARK: - Public API

    /// Sets the delegate for selection events
    @MainActor
    func setDelegate(_ delegate: SelectionOverlayDelegate) {
        overlayView?.delegate = delegate
        overlayView?.displayInfo = displayInfo
    }

    /// Updates the current mouse position for crosshair drawing
    @MainActor
    func updateMousePosition(_ point: NSPoint) {
        overlayView?.mousePosition = point
        overlayView?.needsDisplay = true
    }

    /// Updates the selection state (start point and current point)
    @MainActor
    func updateSelection(start: NSPoint?, current: NSPoint?) {
        overlayView?.selectionStart = start
        overlayView?.selectionCurrent = current
        overlayView?.needsDisplay = true
    }

    /// Shows the overlay window
    @MainActor
    func showOverlay() {
        makeKeyAndOrderFront(nil)
    }

    /// Hides and closes the overlay window
    @MainActor
    func hideOverlay() {
        orderOut(nil)
        close()
    }

    // MARK: - NSWindow Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Make the window accept first responder
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - SelectionOverlayView

/// Custom NSView for drawing the selection overlay.
/// Handles crosshair cursor, dim overlay, and selection rectangle.
final class SelectionOverlayView: NSView {
    // MARK: - Properties

    /// Delegate for selection events
    weak var delegate: SelectionOverlayDelegate?

    /// Display info for coordinate conversion
    var displayInfo: DisplayInfo?

    /// Current mouse position (in window coordinates)
    var mousePosition: NSPoint?

    /// Selection start point (in window coordinates)
    var selectionStart: NSPoint?

    /// Current selection end point (in window coordinates)
    var selectionCurrent: NSPoint?

    /// Currently highlighted window rect (in view coordinates, nil if no window under cursor)
    private var highlightedWindowRect: CGRect? {
        didSet {
            // Only trigger display update when rect actually changes
            if oldValue != highlightedWindowRect {
                needsDisplay = true
            }
        }
    }

    /// Window detector for detecting windows under cursor
    private let windowDetector = WindowDetector.shared

    /// Cached window list for current interaction (refreshed on mouseDown)
    private var cachedWindows: [WindowInfo] = []

    /// Whether the user is currently dragging
    private var isDragging = false

    /// Last mouse moved timestamp for throttling
    private var lastMouseMovedTime: TimeInterval = 0

    /// Throttle interval for window detection (16ms ≈ 60fps)
    private let windowDetectionThrottleInterval: TimeInterval = 0.016

    /// Minimum window size to highlight (10x10 pixels)
    private let minimumWindowSize: CGFloat = 10

    /// Dim overlay color
    private let dimColor = NSColor.black.withAlphaComponent(0.3)

    /// Selection rectangle stroke color
    private let selectionStrokeColor = NSColor.white

    /// Selection rectangle fill color
    private let selectionFillColor = NSColor.white.withAlphaComponent(0.1)

    /// Dimensions label background color
    private let labelBackgroundColor = NSColor.black.withAlphaComponent(0.75)

    /// Dimensions label text color
    private let labelTextColor = NSColor.white

    /// Crosshair line color
    private let crosshairColor = NSColor.white.withAlphaComponent(0.8)

    /// Window highlight fill color (#46E7F0 with 15% alpha - brighter for better visibility)
    private let windowHighlightFillColor = NSColor(red: 0.275, green: 0.906, blue: 0.941, alpha: 0.15)

    /// Window highlight stroke color (#46E7F0 with 90% alpha - much brighter and more visible)
    private let windowHighlightStrokeColor = NSColor(red: 0.275, green: 0.906, blue: 0.941, alpha: 0.9)

    /// Window highlight stroke width (thicker for better visibility)
    private let windowHighlightStrokeWidth: CGFloat = 4.0

    /// Drag threshold for distinguishing click from drag (in points)
    private let dragThreshold: CGFloat = 4.0

    /// Mouse down position for click/drag detection
    private var mouseDownPoint: NSPoint?

    /// Tracking area for mouse moved events
    private var trackingArea: NSTrackingArea?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [
            .activeAlways,
            .mouseMoved,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        setupTrackingArea()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw dim overlay (with cutout for selection or highlighted window)
        drawDimOverlay(context: context)

        // If we have a selection, cut it out and draw the rectangle
        if let start = selectionStart, let current = selectionCurrent {
            let selectionRect = normalizedRect(from: start, to: current)
            drawSelectionRect(selectionRect, context: context)
            drawDimensionsLabel(for: selectionRect, context: context)
        } else {
            // Draw window highlight if there's a highlighted window
            if let highlightRect = highlightedWindowRect {
                drawWindowHighlight(highlightRect, context: context)
                drawDimensionsLabel(for: highlightRect, context: context)
            }

            // Draw crosshair at mouse position
            if let mousePos = mousePosition {
                drawCrosshair(at: mousePos, context: context)
            }
        }
    }

    /// Draws the semi-transparent dim overlay
    /// When there's a selection or highlighted window, creates a cutout using even-odd fill rule
    private func drawDimOverlay(context: CGContext) {
        let hasSelection = selectionStart != nil && selectionCurrent != nil
        let hasHighlightedWindow = highlightedWindowRect != nil && !isDragging

        guard hasSelection || hasHighlightedWindow else {
            // Full dim when not selecting and no highlighted window
            dimColor.setFill()
            bounds.fill()
            return
        }

        context.saveGState()

        // Create path for the entire view
        context.addRect(bounds)

        // Add cutout for selection if present
        if let start = selectionStart, let current = selectionCurrent {
            let selectionRect = normalizedRect(from: start, to: current)
            context.addRect(selectionRect)
        }

        // Add cutout for highlighted window if present (and not dragging)
        if !isDragging, let highlightRect = highlightedWindowRect {
            context.addRect(highlightRect)
        }

        // Use even-odd rule to create the cutout
        context.setFillColor(dimColor.cgColor)
        context.fillPath(using: .evenOdd)

        context.restoreGState()
    }

    /// Draws the selection rectangle with border
    private func drawSelectionRect(_ rect: CGRect, context: CGContext) {
        // Fill
        selectionFillColor.setFill()
        rect.fill()

        // Stroke
        let strokePath = NSBezierPath(rect: rect)
        strokePath.lineWidth = 1.5
        selectionStrokeColor.setStroke()
        strokePath.stroke()

        // Draw dashed inner border
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.addRect(rect.insetBy(dx: 1, dy: 1))
        context.strokePath()
        context.restoreGState()
    }

    /// Draws the crosshair cursor at the specified position
    private func drawCrosshair(at point: NSPoint, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(crosshairColor.cgColor)
        context.setLineWidth(1.0)

        // Horizontal line
        context.move(to: CGPoint(x: 0, y: point.y))
        context.addLine(to: CGPoint(x: bounds.width, y: point.y))

        // Vertical line
        context.move(to: CGPoint(x: point.x, y: 0))
        context.addLine(to: CGPoint(x: point.x, y: bounds.height))

        context.strokePath()
        context.restoreGState()
    }

    /// Draws the window highlight rectangle with border
    private func drawWindowHighlight(_ rect: CGRect, context: CGContext) {
        // Fill
        windowHighlightFillColor.setFill()
        rect.fill()

        // Stroke
        let strokePath = NSBezierPath(rect: rect)
        strokePath.lineWidth = windowHighlightStrokeWidth
        windowHighlightStrokeColor.setStroke()
        strokePath.stroke()
    }

    /// Draws the dimensions label near the selection rectangle
    private func drawDimensionsLabel(for rect: CGRect, context: CGContext) {
        // Get dimensions in pixels (accounting for scale factor)
        let scaleFactor = displayInfo?.scaleFactor ?? 1.0
        let pixelWidth = Int(rect.width * scaleFactor)
        let pixelHeight = Int(rect.height * scaleFactor)

        let dimensionsText = "\(pixelWidth) × \(pixelHeight)"

        // Text attributes - use fallback font if system font unavailable
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium) ?? NSFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: labelTextColor
        ]

        let textSize = (dimensionsText as NSString).size(withAttributes: attributes)
        let labelPadding: CGFloat = 6
        let labelSize = CGSize(
            width: textSize.width + labelPadding * 2,
            height: textSize.height + labelPadding * 2
        )

        // Position the label below and to the right of the selection
        var labelOrigin = CGPoint(
            x: rect.maxX - labelSize.width,
            y: rect.minY - labelSize.height - 8
        )

        // Ensure label stays within screen bounds
        if labelOrigin.x < 0 {
            labelOrigin.x = rect.minX
        }
        if labelOrigin.y < 0 {
            labelOrigin.y = rect.maxY + 8
        }
        if labelOrigin.x + labelSize.width > bounds.width {
            labelOrigin.x = bounds.width - labelSize.width
        }

        let labelRect = CGRect(origin: labelOrigin, size: labelSize)

        // Draw background
        let backgroundPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        labelBackgroundColor.setFill()
        backgroundPath.fill()

        // Draw text
        let textPoint = CGPoint(
            x: labelRect.origin.x + labelPadding,
            y: labelRect.origin.y + labelPadding
        )
        (dimensionsText as NSString).draw(at: textPoint, withAttributes: attributes)
    }

    /// Creates a normalized rectangle from two points (handles any drag direction)
    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> CGRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseDownPoint = point

        // Refresh window cache when starting interaction to get fresh window list
        Task {
            await windowDetector.invalidateCache()
            let windows = await windowDetector.visibleWindows()
            await MainActor.run {
                self.cachedWindows = windows
            }
        }

        // Don't start selection yet - wait to determine if it's a click or drag
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownPoint = mouseDownPoint else { return }

        let point = convert(event.locationInWindow, from: nil)

        // Calculate distance from mouse down point
        let distance = hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y)

        // If we haven't started dragging yet and moved beyond threshold, enter drag mode
        if !isDragging && distance > dragThreshold {
            isDragging = true
            selectionStart = mouseDownPoint
            selectionCurrent = point

            // Clear highlighted window when entering drag mode
            highlightedWindowRect = nil
        } else if isDragging {
            selectionCurrent = point
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownPoint != nil else { return }

        if isDragging {
            // === DRAG MODE ===
            guard let start = selectionStart, let current = selectionCurrent else {
                resetStateAndCancel()
                return
            }

            isDragging = false

            // Calculate final selection rectangle
            let selectionRect = normalizedRect(from: start, to: current)

            // Only accept selection if it has meaningful size
            if selectionRect.width >= 10 && selectionRect.height >= 10 {
                // Convert to screen coordinates
                guard let window = self.window,
                      let displayInfo = displayInfo else {
                    resetStateAndCancel()
                    return
                }

                Logger.capture.debug("=== SELECTION COORDINATE DEBUG ===")
                Logger.capture.debug("[1] selectionRect (view coords): \(String(describing: selectionRect))")
                Logger.capture.debug("[2] window.frame: \(String(describing: window.frame))")
                Logger.capture.debug("[3] window.screen?.frame: \(String(describing: window.screen?.frame))")

                // The selectionRect is in view coordinates, convert to screen coordinates
                // screenRect is in Cocoa coordinates (Y=0 at bottom of primary screen)
                let screenRect = window.convertToScreen(selectionRect)

                Logger.capture.debug("[4] screenRect (after convertToScreen): \(String(describing: screenRect))")
                let firstScreenFrame = NSScreen.screens.first?.frame
                Logger.capture.debug("[5] NSScreen.screens.first?.frame: \(String(describing: firstScreenFrame))")

                // Get the screen height for coordinate conversion
                // Use the window's screen, not necessarily the primary screen
                // Cocoa uses Y=0 at bottom, ScreenCaptureKit/Quartz uses Y=0 at top
                let screenHeight = window.screen?.frame.height ?? NSScreen.screens.first?.frame.height ?? 0

                Logger.capture.debug("[6] screenHeight for conversion: \(screenHeight)")

                // Convert from Cocoa coordinates (Y=0 at bottom) to Quartz coordinates (Y=0 at top)
                let quartzY = screenHeight - screenRect.origin.y - screenRect.height

                Logger.capture.debug("[7] quartzY (converted): \(quartzY)")

                // displayFrame is in Quartz coordinates (from SCDisplay)
                let displayFrame = displayInfo.frame

                Logger.capture.debug("[8] displayInfo.frame (SCDisplay): \(String(describing: displayFrame))")
                Logger.capture.debug("[9] displayInfo.isPrimary: \(displayInfo.isPrimary)")

                // Now compute display-relative coordinates (both in Quartz coordinate system)
                // Round to whole points to minimize fractional pixel issues when scaled
                let relativeRect = CGRect(
                    x: round(screenRect.origin.x - displayFrame.origin.x),
                    y: round(quartzY - displayFrame.origin.y),
                    width: round(selectionRect.width),
                    height: round(selectionRect.height)
                )

                Logger.capture.debug("[10] FINAL relativeRect (rounded): \(String(describing: relativeRect))")
                let normX = relativeRect.origin.x / displayFrame.width
                let normY = relativeRect.origin.y / displayFrame.height
                Logger.capture.debug("[11] Normalized would be: x=\(normX), y=\(normY)")
                Logger.capture.debug("=== END COORDINATE DEBUG ===")

                resetState()
                delegate?.selectionOverlay(didSelectRect: relativeRect, on: displayInfo)
            } else {
                // Too small - cancel
                resetStateAndCancel()
            }
        } else {
            // === CLICK MODE ===
            if let highlightRect = highlightedWindowRect {
                // Click on a highlighted window - use window rect
                guard let window = self.window,
                      let displayInfo = displayInfo else {
                    resetStateAndCancel()
                    return
                }

                Logger.capture.debug("=== CLICK MODE - WINDOW SELECTION ===")
                Logger.capture.debug("[1] highlightRect (view coords): \(String(describing: highlightRect))")

                // Convert highlight rect to screen coordinates
                let screenRect = window.convertToScreen(highlightRect)

                Logger.capture.debug("[2] screenRect (after convertToScreen): \(String(describing: screenRect))")

                // Get screen height for coordinate conversion
                let screenHeight = window.screen?.frame.height ?? NSScreen.screens.first?.frame.height ?? 0
                Logger.capture.debug("[3] screenHeight for conversion: \(screenHeight)")

                // Convert from Cocoa to Quartz coordinates
                let quartzY = screenHeight - screenRect.origin.y - screenRect.height

                Logger.capture.debug("[4] quartzY (converted): \(quartzY)")

                let displayFrame = displayInfo.frame
                Logger.capture.debug("[5] displayInfo.frame (SCDisplay): \(String(describing: displayFrame))")

                // Compute display-relative coordinates
                let relativeRect = CGRect(
                    x: round(screenRect.origin.x - displayFrame.origin.x),
                    y: round(quartzY - displayFrame.origin.y),
                    width: round(highlightRect.width),
                    height: round(highlightRect.height)
                )

                Logger.capture.debug("[6] FINAL relativeRect (rounded): \(String(describing: relativeRect))")
                Logger.capture.debug("=== END CLICK MODE ===")

                resetState()
                delegate?.selectionOverlay(didSelectRect: relativeRect, on: displayInfo)
            } else {
                // Click on empty area - cancel
                resetStateAndCancel()
            }
        }
    }

    /// Resets all state variables
    private func resetState() {
        mouseDownPoint = nil
        selectionStart = nil
        selectionCurrent = nil
        isDragging = false
        highlightedWindowRect = nil
        cachedWindows = []
        lastMouseMovedTime = 0
        needsDisplay = true
    }

    /// Resets state and notifies delegate of cancellation
    private func resetStateAndCancel() {
        resetState()
        delegate?.selectionOverlayDidCancel()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mousePosition = point

        // Only detect windows when not dragging
        if !isDragging {
            // Throttle window detection to ~60fps (16ms)
            let currentTime = Date.timeIntervalSinceReferenceDate
            if currentTime - lastMouseMovedTime >= windowDetectionThrottleInterval {
                lastMouseMovedTime = currentTime
                updateHighlightedWindow(at: point)
            }
        }

        // Always update crosshair position (not throttled)
        needsDisplay = true
    }

    /// Updates the highlighted window based on the current mouse position.
    /// Detects the window under the cursor and converts its frame to view coordinates.
    /// - Parameter point: The current mouse position in view coordinates
    private func updateHighlightedWindow(at point: NSPoint) {
        guard let window = self.window else {
            highlightedWindowRect = nil
            return
        }

        // Convert point from view coordinates to screen coordinates (Cocoa)
        let screenPoint = window.convertToScreen(
            NSRect(origin: point, size: .zero)
        ).origin

        // Convert from Cocoa coordinates (origin at bottom-left) to Quartz coordinates (origin at top-left)
        let screenHeight = window.screen?.frame.height ?? NSScreen.main?.frame.height ?? 0
        let quartzPoint = WindowDetector.cocoaToQuartz(screenPoint, screenHeight: screenHeight)

        // Find window under point using WindowDetector (synchronous call)
        // WindowDetector has its own internal cache for performance
        Task {
            if let windowInfo = await windowDetector.windowUnderPoint(quartzPoint) {
                // Skip windows smaller than minimum size
                guard windowInfo.frame.width >= minimumWindowSize &&
                      windowInfo.frame.height >= minimumWindowSize else {
                    await MainActor.run {
                        highlightedWindowRect = nil
                    }
                    return
                }

                // Convert window frame from Quartz to Cocoa coordinates
                let cocoaFrame = WindowDetector.quartzToCocoa(windowInfo.frame, screenHeight: screenHeight)

                // Convert from screen coordinates to view coordinates
                var viewFrame = self.convertFromScreen(cocoaFrame)

                // Clip the highlight rect to the visible screen bounds
                viewFrame = viewFrame.intersection(self.bounds)

                // Only set if the clipped rect is still valid
                await MainActor.run {
                    if !viewFrame.isEmpty {
                        highlightedWindowRect = viewFrame
                    } else {
                        highlightedWindowRect = nil
                    }
                }
            } else {
                await MainActor.run {
                    highlightedWindowRect = nil
                }
            }
        }
    }

    /// Converts a rectangle from screen coordinates to view coordinates.
    /// - Parameter screenRect: Rectangle in screen coordinates (Cocoa)
    /// - Returns: Rectangle in view coordinates
    private func convertFromScreen(_ screenRect: CGRect) -> CGRect {
        guard let window = self.window else {
            return screenRect
        }

        // Get the window's frame in screen coordinates
        let windowFrame = window.frame

        // View coordinates are relative to the window's content view
        // The view's origin (0,0) is at the bottom-left of the window in Cocoa coordinates
        let viewX = screenRect.origin.x - windowFrame.origin.x
        let viewY = screenRect.origin.y - windowFrame.origin.y

        return CGRect(
            x: viewX,
            y: viewY,
            width: screenRect.width,
            height: screenRect.height
        )
    }

    override func mouseEntered(with event: NSEvent) {
        // Change cursor to crosshair
        NSCursor.crosshair.set()
    }

    override func mouseExited(with event: NSEvent) {
        // Reset cursor
        NSCursor.arrow.set()
        mousePosition = nil
        needsDisplay = true
    }

    // MARK: - Keyboard Events

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape key cancels selection and closes overlay
        if event.keyCode == 53 { // Escape
            // Reset all state including window highlight
            resetStateAndCancel()
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}

// MARK: - SelectionOverlayController

/// Controller for managing selection overlay windows across all displays.
/// Creates and coordinates overlay windows for multi-display spanning selection.
@MainActor
final class SelectionOverlayController {
    // MARK: - Properties

    /// Shared instance
    static let shared = SelectionOverlayController()

    /// All active overlay windows (one per display)
    private var overlayWindows: [SelectionOverlayWindow] = []

    /// Delegate for selection events
    weak var delegate: SelectionOverlayDelegate?

    /// Callback for when selection completes
    var onSelectionComplete: ((CGRect, DisplayInfo) -> Void)?

    /// Callback for when selection is cancelled
    var onSelectionCancel: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Presents selection overlay on all connected displays.
    func presentOverlay() async throws {
        // Get all available displays
        let displays = try await ScreenDetector.shared.availableDisplays()

        // Get matching screens
        let screens = NSScreen.screens

        // Create overlay window for each display
        for display in displays {
            guard let screen = screens.first(where: { screen in
                guard let screenNumber = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? CGDirectDisplayID else {
                    return false
                }
                return screenNumber == display.id
            }) else {
                continue
            }

            let overlayWindow = SelectionOverlayWindow(screen: screen, displayInfo: display)
            overlayWindow.setDelegate(self)
            overlayWindows.append(overlayWindow)
        }

        // Show all overlay windows
        for window in overlayWindows {
            window.showOverlay()
        }

        // Make the first window (primary display) key
        if let primaryWindow = overlayWindows.first {
            primaryWindow.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Dismisses all overlay windows.
    func dismissOverlay() {
        for window in overlayWindows {
            window.hideOverlay()
        }
        overlayWindows.removeAll()

        // Reset cursor
        NSCursor.arrow.set()
    }
}

// MARK: - SelectionOverlayController + SelectionOverlayDelegate

extension SelectionOverlayController: SelectionOverlayDelegate {
    func selectionOverlay(didSelectRect rect: CGRect, on display: DisplayInfo) {
        // Dismiss all overlays first
        dismissOverlay()

        // Notify via callback
        onSelectionComplete?(rect, display)
    }

    func selectionOverlayDidCancel() {
        // Dismiss all overlays
        dismissOverlay()

        // Notify via callback
        onSelectionCancel?()
    }
}
