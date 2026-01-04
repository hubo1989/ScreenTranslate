# Research: ScreenCapture

**Branch**: `001-screen-capture` | **Date**: 2026-01-04
**Purpose**: Technology decisions and best practices for implementation

## 1. Screen Capture API

### Decision: ScreenCaptureKit

Use Apple's ScreenCaptureKit framework for all capture operations.

### Rationale

- **Modern API**: Introduced in macOS 12.3, actively maintained
- **Multi-display**: Native support via `SCShareableContent.displays`
- **Performance**: Metal-backed, designed for real-time capture
- **Permissions**: Integrated with TCC (Transparency, Consent, Control)
- **Single-frame capture**: `SCScreenshotManager.captureImage()` for instant captures

### Implementation Pattern

```swift
// Enumerate displays
let content = try await SCShareableContent.getWithCompletionHandler { content, error in
    guard let content else { return }
    let displays = content.displays  // [SCDisplay]
}

// Capture single display
let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
let config = SCStreamConfiguration()
config.width = display.width
config.height = display.height

let image = try await SCScreenshotManager.captureImage(
    contentFilter: filter,
    configuration: config
)
```

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| CGWindowListCreateImage | Deprecated; no ScreenCaptureKit parity |
| AVFoundation screen recording | Overkill for single-frame capture |
| Third-party capture libs | Adds dependency; Apple API sufficient |

---

## 2. Global Hotkey Registration

### Decision: Carbon RegisterEventHotKey

Use the Carbon `RegisterEventHotKey` API wrapped in a Swift actor for global shortcuts.

### Rationale

- **Sandbox compatible**: Works with App Sandbox (macOS 10.15+)
- **No input monitoring**: Unlike CGEventTap, doesn't require Input Monitoring privilege
- **Stable**: Despite being Carbon-era, widely used and maintained by Apple
- **macOS 15 fix**: Known Option-only modifier issue (FB15168205) was fixed

### Implementation Pattern

```swift
actor HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?

    func register(keyCode: UInt32, modifiers: UInt32, id: UInt32) throws {
        var hotkeyID = EventHotKeyID(signature: OSType("SCRN"), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )
        guard status == noErr else { throw HotkeyError.registrationFailed }
    }
}
```

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| CGEventTap | Requires Input Monitoring permission; complex setup |
| KeyboardShortcuts package | External dependency; we want zero dependencies |
| HotKey package | External dependency |
| AppKit globalMonitor | Doesn't work when app is not frontmost |

---

## 3. Selection Overlay Window

### Decision: NSPanel with custom drawing

Use NSPanel subclass for the full-screen selection overlay.

### Rationale

- **Always on top**: `.floating` window level
- **Transparent background**: Can overlay without obscuring content
- **Mouse tracking**: Direct access to NSEvent for crosshair + drag
- **Multi-display**: Create one panel per display for seamless selection

### Implementation Pattern

```swift
class SelectionOverlayWindow: NSPanel {
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
    }
}
```

### Selection Rectangle Drawing

- Use Core Animation layer for smooth dimension label updates
- Display "1234 × 567" near cursor during drag
- Dim unselected area with semi-transparent overlay

---

## 4. Preview Window

### Decision: NSPanel hosting NSHostingView<SwiftUI>

Use NSPanel to host SwiftUI content for the preview/annotation editor.

### Rationale

- **Always on top**: Panel behavior keeps preview visible
- **SwiftUI for UI**: Modern, declarative annotation tools
- **AppKit integration**: Proper window management, keyboard handling
- **Floating panel pattern**: Standard macOS utility window behavior

### Implementation Pattern

```swift
class PreviewWindow: NSPanel {
    init(image: CGImage, viewModel: PreviewViewModel) {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        level = .floating
        contentView = NSHostingView(rootView: PreviewContentView(viewModel: viewModel))
    }
}
```

---

## 5. Annotation Canvas

### Decision: SwiftUI Canvas with gesture recognizers

Use SwiftUI Canvas view for immediate-mode drawing of annotations.

### Rationale

- **Performance**: Metal-backed rendering for 60fps drawing
- **Immediate mode**: No retained graphics objects; efficient for overlays
- **Path drawing**: Native support for CGPath/Path operations
- **Coordinate system**: Direct mapping to image coordinates

### Implementation Pattern

```swift
struct AnnotationCanvas: View {
    @ObservedObject var viewModel: PreviewViewModel

    var body: some View {
        Canvas { context, size in
            // Draw base image
            context.draw(Image(viewModel.cgImage, scale: 1, label: Text("")), at: .zero)

            // Draw annotations
            for annotation in viewModel.annotations {
                switch annotation {
                case .rectangle(let rect, let style):
                    context.stroke(Path(rect), with: .color(style.color), lineWidth: style.width)
                case .freehand(let points, let style):
                    var path = Path()
                    path.addLines(points)
                    context.stroke(path, with: .color(style.color), lineWidth: style.width)
                case .text(let position, let content, let style):
                    context.draw(Text(content).font(style.font), at: position)
                }
            }
        }
        .gesture(viewModel.currentToolGesture)
    }
}
```

---

## 6. Menu Bar Integration

### Decision: NSStatusItem with NSMenu

Use AppKit's NSStatusItem for menu bar presence.

### Rationale

- **Native**: Standard macOS menu bar API
- **No dock icon**: Set LSUIElement = true in Info.plist
- **Menu construction**: NSMenu with keyboard shortcut display
- **SwiftUI not sufficient**: NSStatusItem requires AppKit

### Implementation Pattern

```swift
@MainActor
class MenuBarController {
    private var statusItem: NSStatusItem?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ScreenCapture")
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: "3")
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        // ... additional items
        return menu
    }
}
```

---

## 7. Image Export

### Decision: CGImageDestination with UTType

Use Core Graphics image I/O for PNG/JPEG encoding.

### Rationale

- **Native**: No external dependencies
- **Format support**: PNG, JPEG with quality control
- **Performance**: Optimized for Apple Silicon
- **UniformTypeIdentifiers**: Modern type system for file types

### Implementation Pattern

```swift
struct ImageExporter {
    func export(_ image: CGImage, to url: URL, format: ExportFormat) throws {
        let uti: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, uti.identifier as CFString, 1, nil
        ) else { throw ExportError.destinationCreationFailed }

        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = format.quality
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.finalizationFailed
        }
    }
}
```

---

## 8. Undo/Redo Stack

### Decision: Value-type annotation stack with UndoManager integration

Implement undo using Swift's value semantics and AppKit's UndoManager.

### Rationale

- **Value types**: Annotations as structs enable copy-on-write undo
- **UndoManager**: Native Cmd+Z/Cmd+Shift+Z support
- **Responder chain**: Automatic menu item enabling

### Implementation Pattern

```swift
@Observable
class PreviewViewModel {
    var annotations: [Annotation] = []
    private var undoManager = UndoManager()

    func addAnnotation(_ annotation: Annotation) {
        let previousState = annotations
        annotations.append(annotation)

        undoManager.registerUndo(withTarget: self) { target in
            target.annotations = previousState
        }
    }
}
```

---

## 9. Accessibility

### Decision: Full VoiceOver and keyboard navigation support

Implement accessibility per Apple HIG and constitution requirements.

### Rationale

- **Constitution Principle VI**: Required for compliance
- **Legal**: WCAG/Section 508 considerations
- **UX**: Keyboard-first workflow benefits all users

### Implementation Checklist

- [ ] All buttons have accessibility labels
- [ ] Tool selection announced to VoiceOver
- [ ] Tab navigation through preview controls
- [ ] Escape dismisses overlay/preview
- [ ] Reduce Motion: disable non-essential animations
- [ ] High Contrast: ensure annotation colors remain visible

---

## 10. Entitlements and Permissions

### Decision: Minimal entitlements with clear permission prompts

Request only necessary permissions with user-friendly explanations.

### Required Entitlements

```xml
<!-- ScreenCapture.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.apple.finder</string>
</array>
```

### Screen Recording Permission

ScreenCaptureKit triggers the system permission prompt automatically.
Provide a clear explanation in Info.plist:

```xml
<key>NSScreenCaptureUsageDescription</key>
<string>ScreenCapture needs access to record your screen to capture screenshots.</string>
```

---

## Sources

- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [Apple Developer Forums: Global Hotkeys](https://developer.apple.com/forums/thread/735223)
- [Mastering Canvas in SwiftUI](https://swiftwithmajid.com/2023/04/11/mastering-canvas-in-swiftui/)
- [Floating Panel in SwiftUI for macOS](https://cindori.com/developer/floating-panel)
- [NSPanel Documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
