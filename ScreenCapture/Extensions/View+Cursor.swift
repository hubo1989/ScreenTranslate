import SwiftUI
import AppKit

/// Extension to add cursor support to SwiftUI views
extension View {
    /// Sets the cursor to use when hovering over this view
    /// - Parameter cursor: The NSCursor to display
    /// - Returns: A view that changes the cursor on hover
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    /// Adds scroll wheel zoom handling to the view
    /// - Parameter action: Closure called with the scroll delta (positive = up/zoom in)
    func onScrollWheelZoom(action: @escaping (CGFloat) -> Void) -> some View {
        self.background(
            ScrollWheelZoomView(action: action)
        )
    }
}

// MARK: - Scroll Wheel Zoom Handler

/// NSViewRepresentable that captures scroll wheel events for zooming
private struct ScrollWheelZoomView: NSViewRepresentable {
    let action: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelCaptureView {
        let view = ScrollWheelCaptureView()
        view.onScrollWheel = action
        return view
    }

    func updateNSView(_ nsView: ScrollWheelCaptureView, context: Context) {
        nsView.onScrollWheel = action
    }
}

/// Custom NSView that captures scroll wheel events
private class ScrollWheelCaptureView: NSView {
    var onScrollWheel: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        // Only handle scroll wheel zoom when Command key is held
        // or when using a mouse (not trackpad for scrolling)
        if event.modifierFlags.contains(.command) || event.phase == .none {
            // Use deltaY for vertical scroll (zoom)
            let delta = event.scrollingDeltaY
            if abs(delta) > 0.1 {
                onScrollWheel?(delta)
            }
        } else {
            // Pass through to parent for normal scrolling
            super.scrollWheel(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
