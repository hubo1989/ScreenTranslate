//
//  TextInsertionProgressController.swift
//  TransFrame
//
//  Shows a small non-activating progress indicator near the current text cursor
//  while translate-and-insert is running.
//

import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class TextInsertionProgressController {
    static let shared = TextInsertionProgressController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<TextInsertionProgressView>?

    private init() {}

    func show(message: String) {
        let anchor = TextCursorLocator.currentCursorRect() ?? TextCursorLocator.mouseFallbackRect()

        if panel == nil {
            createPanel(message: message)
        } else {
            update(message: message)
        }

        positionPanel(near: anchor)
        panel?.orderFrontRegardless()
    }

    func update(message: String) {
        guard let hostingView else { return }
        hostingView.rootView = TextInsertionProgressView(message: message)
    }

    func dismiss() {
        panel?.close()
        panel = nil
        hostingView = nil
    }

    private func createPanel(message: String) {
        let contentView = TextInsertionProgressView(message: message)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 172, height: 44)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        self.panel = panel
        self.hostingView = hostingView
    }

    private func positionPanel(near anchor: CGRect) {
        guard let panel else { return }

        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        let padding: CGFloat = 10
        var origin = CGPoint(
            x: anchor.maxX + padding,
            y: anchor.midY - size.height / 2
        )

        if origin.x + size.width > screenFrame.maxX - padding {
            origin.x = anchor.minX - size.width - padding
        }

        origin.x = min(max(origin.x, screenFrame.minX + padding), screenFrame.maxX - size.width - padding)
        origin.y = min(max(origin.y, screenFrame.minY + padding), screenFrame.maxY - size.height - padding)

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

private struct TextInsertionProgressView: View {
    let message: String

    @State private var isPulsing = false
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(isPulsing ? 0.18 : 0.5), lineWidth: 3)
                    .scaleEffect(isPulsing ? 1.35 : 0.8)

                Circle()
                    .trim(from: 0.12, to: 0.82)
                    .stroke(Color.accentColor, style: SwiftUI.StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 20, height: 20)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 172, height: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

private enum TextCursorLocator {
    static func currentCursorRect() -> CGRect? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedObject: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success,
        let focusedElement = focusedObject else {
            return nil
        }

        let element = focusedElement as! AXUIElement
        var selectedRangeObject: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeObject
        ) == .success,
        let selectedRangeObject else {
            return nil
        }

        let selectedRangeValue = selectedRangeObject as! AXValue

        var boundsObject: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRangeValue,
            &boundsObject
        ) == .success,
        let boundsObject else {
            return nil
        }

        let boundsValue = boundsObject as! AXValue

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue, .cgRect, &rect), !rect.isNull, !rect.isEmpty else {
            return nil
        }

        return rect
    }

    static func mouseFallbackRect() -> CGRect {
        let mouse = NSEvent.mouseLocation
        return CGRect(x: mouse.x, y: mouse.y, width: 1, height: 22)
    }
}
