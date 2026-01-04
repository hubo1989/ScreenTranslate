# Architecture

This document describes the overall architecture, design patterns, and key decisions in the ScreenCapture application.

## High-Level Architecture

ScreenCapture follows a **feature-based modular architecture** with clear separation of concerns. The application is structured around distinct features, each encapsulated in its own module.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Application Layer                        │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │ ScreenCaptureApp │  │   AppDelegate    │                     │
│  │   (SwiftUI)      │  │   (Lifecycle)    │                     │
│  └────────┬─────────┘  └────────┬─────────┘                     │
└───────────┼─────────────────────┼───────────────────────────────┘
            │                     │
┌───────────┼─────────────────────┼───────────────────────────────┐
│           │     Feature Layer   │                               │
│  ┌────────▼────────┐   ┌────────▼────────┐   ┌────────────────┐ │
│  │  MenuBar        │   │   Capture       │   │   Preview      │ │
│  │  Controller     │   │   Manager       │   │   Window       │ │
│  └─────────────────┘   └─────────────────┘   └────────────────┘ │
│                                                                  │
│  ┌─────────────────┐   ┌─────────────────┐   ┌────────────────┐ │
│  │  Annotations    │   │   Settings      │   │   Selection    │ │
│  │  System         │   │   View          │   │   Overlay      │ │
│  └─────────────────┘   └─────────────────┘   └────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
            │                     │                    │
┌───────────┼─────────────────────┼────────────────────┼───────────┐
│           │     Service Layer   │                    │           │
│  ┌────────▼────────┐   ┌────────▼────────┐   ┌───────▼────────┐ │
│  │ ImageExporter   │   │ ClipboardService│   │ HotkeyManager  │ │
│  └─────────────────┘   └─────────────────┘   └────────────────┘ │
│                                                                  │
│  ┌─────────────────┐   ┌─────────────────┐                      │
│  │ RecentCaptures  │   │ ScreenDetector  │                      │
│  │ Store           │   │                 │                      │
│  └─────────────────┘   └─────────────────┘                      │
└──────────────────────────────────────────────────────────────────┘
            │                     │
┌───────────┼─────────────────────┼───────────────────────────────┐
│           │     Model Layer     │                               │
│  ┌────────▼────────┐   ┌────────▼────────┐   ┌────────────────┐ │
│  │   Screenshot    │   │   DisplayInfo   │   │   Annotation   │ │
│  └─────────────────┘   └─────────────────┘   └────────────────┘ │
│                                                                  │
│  ┌─────────────────┐   ┌─────────────────┐   ┌────────────────┐ │
│  │   AppSettings   │   │   ExportFormat  │   │     Styles     │ │
│  └─────────────────┘   └─────────────────┘   └────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## Design Patterns

### 1. Actor-Based Concurrency

Thread-safe components use Swift's actor model for isolation:

```swift
actor CaptureManager {
    static let shared = CaptureManager()

    func captureFullScreen(display: DisplayInfo) async throws -> Screenshot
    func captureRegion(_ region: CGRect, from display: DisplayInfo) async throws -> Screenshot
}
```

**Actors used:**
- `CaptureManager` - Thread-safe screenshot capture
- `ScreenDetector` - Display enumeration with caching
- `HotkeyManager` - Global hotkey registration

### 2. Observable Pattern

State management uses Swift's `@Observable` macro for SwiftUI reactivity:

```swift
@Observable
final class PreviewViewModel {
    var screenshot: Screenshot
    var selectedTool: AnnotationToolType?
    var annotations: [Annotation]
}
```

**Observable classes:**
- `PreviewViewModel` - Preview window state
- `AppSettings` - Persistent preferences
- `SettingsViewModel` - Settings UI state

### 3. Singleton Pattern

Shared instances for global services:

```swift
class AppSettings {
    static let shared = AppSettings()
}

actor CaptureManager {
    static let shared = CaptureManager()
}
```

### 4. Protocol-Based Design

Annotation tools follow a common protocol:

```swift
protocol AnnotationTool {
    var currentAnnotation: Annotation? { get }

    mutating func beginDrawing(at point: CGPoint, style: StrokeStyle)
    mutating func continueDrawing(to point: CGPoint)
    mutating func endDrawing(at point: CGPoint) -> Annotation?
    mutating func cancelDrawing()
}
```

**Tool implementations:**
- `RectangleTool`
- `FreehandTool`
- `ArrowTool`
- `TextTool`

### 5. Immutable Value Types

Models are immutable structs with functional update methods:

```swift
struct Screenshot: Identifiable, Sendable {
    let image: CGImage
    let annotations: [Annotation]

    func adding(_ annotation: Annotation) -> Screenshot {
        var copy = self
        copy.annotations.append(annotation)
        return copy
    }
}
```

### 6. Delegation Pattern

UI components use delegation for callbacks:

```swift
protocol SelectionOverlayDelegate: AnyObject {
    func selectionCompleted(rect: CGRect, display: DisplayInfo)
    func selectionCancelled()
}
```

## Data Flow

### Capture Flow

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   Hotkey    │────▶│  AppDelegate │────▶│ DisplaySelect│
│   Press     │     │             │     │              │
└─────────────┘     └─────────────┘     └──────┬───────┘
                                               │
                    ┌─────────────────────────┘
                    ▼
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│  Capture    │◀────│   Screen    │     │   Preview    │
│  Manager    │     │   Capture   │────▶│   Window     │
└─────────────┘     │   Kit       │     └──────────────┘
                    └─────────────┘
```

1. User presses hotkey (`Cmd+Shift+3` or `Cmd+Shift+4`)
2. `AppDelegate` receives callback from `HotkeyManager`
3. For multi-monitor: `DisplaySelector` shows selection menu
4. `CaptureManager` calls ScreenCaptureKit APIs
5. `Screenshot` model created with image and metadata
6. `PreviewWindow` displayed for annotation/save

### Annotation Flow

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   Mouse     │────▶│  Preview    │────▶│  Annotation  │
│   Event     │     │  ViewModel  │     │    Tool      │
└─────────────┘     └─────────────┘     └──────┬───────┘
                                               │
                    ┌─────────────────────────┘
                    ▼
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│  Screenshot │◀────│  Annotation │     │   Canvas     │
│  Model      │     │  Created    │────▶│   Redraw     │
└─────────────┘     └─────────────┘     └──────────────┘
```

1. User selects annotation tool (keyboard or click)
2. Mouse events routed to `PreviewViewModel`
3. Active `AnnotationTool` builds annotation incrementally
4. On completion, `Annotation` added to `Screenshot`
5. Canvas redraws to show annotation

### Export Flow

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│    Save     │────▶│   Image     │────▶│  Composite   │
│   Action    │     │  Exporter   │     │  Annotations │
└─────────────┘     └─────────────┘     └──────┬───────┘
                                               │
                    ┌─────────────────────────┘
                    ▼
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   Recent    │◀────│   Write     │     │   Format     │
│  Captures   │     │   To Disk   │────▶│  PNG/JPEG    │
└─────────────┘     └─────────────┘     └──────────────┘
```

## Threading Model

### Main Thread (`@MainActor`)

UI components and user interaction:
- `AppDelegate`
- `PreviewWindow`
- `PreviewViewModel`
- `MenuBarController`
- `SettingsView`
- `ClipboardService`
- `RecentCapturesStore`

### Actor Isolation

Concurrent operations with thread safety:
- `CaptureManager` - Capture operations
- `ScreenDetector` - Display enumeration
- `HotkeyManager` - Hotkey registration

### Background Tasks

Heavy operations off main thread:
- Image encoding (PNG/JPEG)
- Thumbnail generation
- File I/O

## Memory Management

### Image Lifecycle

```
Capture          Preview           Save            Cleanup
   │                │                │                │
   ▼                ▼                ▼                ▼
┌──────┐      ┌──────────┐     ┌──────────┐     ┌────────┐
│CGImage│────▶│Screenshot│────▶│Composited│────▶│Released│
│~10MB │      │  + Meta  │     │  + Write │     │        │
└──────┘      └──────────┘     └──────────┘     └────────┘
```

**Memory bounds:**
- Captured image: ~10MB (4K @ 32bpp)
- Annotations: Minimal (path data only)
- Compositing: Transient (released after write)
- Thumbnails: 10KB max (128px JPEG)

### Caching Strategy

- `ScreenDetector`: 5-second display list cache
- `RecentCapturesStore`: Max 5 entries with thumbnails
- Undo stack: Max 50 states

## Error Handling Strategy

### Error Types

All errors conform to `LocalizedError`:

```swift
enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case captureFailure(underlying: Error)
    case exportEncodingFailed
    // ...

    var errorDescription: String? { /* ... */ }
    var recoverySuggestion: String? { /* ... */ }
}
```

### Error Presentation

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   Error     │────▶│   Format    │────▶│   Alert      │
│  Thrown     │     │   Message   │     │   Dialog     │
└─────────────┘     └─────────────┘     └──────────────┘
```

Errors include:
- User-friendly description
- Technical details (if available)
- Recovery suggestions

## Security Considerations

### Permissions

1. **Screen Recording** - Required for ScreenCaptureKit
   - Requested on first launch
   - Graceful degradation with error message

2. **File System** - Save location access
   - Security-scoped bookmarks for persistence
   - Validation before write

### Global Hotkeys

Uses Carbon `RegisterEventHotKey` API:
- Sandboxing compatible (vs. IOKit)
- Per-app registration with signature
- Automatic cleanup on termination

## Performance Targets

| Operation | Target | Monitoring |
|-----------|--------|------------|
| Capture latency | <50ms | OSSignpost |
| Preview display | <100ms | Manual |
| Idle CPU | <1% | Activity Monitor |
| Memory (idle) | <50MB | Instruments |

## Extension Points

### Adding New Annotation Tools

1. Create struct conforming to `AnnotationTool`
2. Add case to `Annotation` enum
3. Add case to `AnnotationToolType` enum
4. Update `PreviewViewModel` tool handling
5. Add keyboard shortcut in `PreviewWindow`

### Adding Export Formats

1. Add case to `ExportFormat` enum
2. Implement encoding in `ImageExporter`
3. Update settings UI if needed
