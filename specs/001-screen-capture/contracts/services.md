# Service Contracts: ScreenCapture

**Branch**: `001-screen-capture` | **Date**: 2026-01-04
**Purpose**: Internal API contracts between services and ViewModels

## Overview

This document defines the public interfaces for services used by ViewModels.
All services are injected via protocol conformance to enable testing.

---

## 1. CaptureService

Handles screen capture operations using ScreenCaptureKit.

### Protocol

```swift
protocol CaptureServiceProtocol: Sendable {
    /// Capture entire display
    func captureFullScreen(display: DisplayInfo) async throws -> CGImage

    /// Capture selected region
    func captureRegion(_ rect: CGRect, from display: DisplayInfo) async throws -> CGImage

    /// Get all available displays
    func availableDisplays() async throws -> [DisplayInfo]

    /// Check screen recording permission status
    var hasPermission: Bool { get async }

    /// Request screen recording permission
    func requestPermission() async -> Bool
}
```

### Errors

| Error | When |
|-------|------|
| `permissionDenied` | Screen recording not authorized |
| `displayNotFound` | Target display disconnected |
| `captureFailure` | ScreenCaptureKit internal error |

### Concurrency

- All methods are `async` and can be called from any actor
- Display enumeration updates via `AsyncStream<[DisplayInfo]>`

---

## 2. ImageExportService

Encodes and saves captured images.

### Protocol

```swift
protocol ImageExportServiceProtocol: Sendable {
    /// Export image to file
    func save(
        _ image: CGImage,
        annotations: [Annotation],
        to url: URL,
        format: ExportFormat,
        quality: Double
    ) async throws

    /// Generate filename with timestamp
    func generateFilename(format: ExportFormat) -> String

    /// Estimate file size before saving
    func estimateFileSize(
        for image: CGImage,
        format: ExportFormat,
        quality: Double
    ) -> Int
}
```

### Errors

| Error | When |
|-------|------|
| `invalidSaveLocation` | Directory doesn't exist or no write permission |
| `diskFull` | Insufficient disk space |
| `exportEncodingFailed` | CGImageDestination failure |

### File Naming

Format: `Screenshot YYYY-MM-DD at HH.MM.SS.{png|jpg}`

---

## 3. ClipboardService

Manages pasteboard operations.

### Protocol

```swift
protocol ClipboardServiceProtocol: Sendable {
    /// Copy image with annotations to clipboard
    func copy(_ image: CGImage, annotations: [Annotation]) async throws

    /// Check if clipboard contains image
    var hasImage: Bool { get }
}
```

### Errors

| Error | When |
|-------|------|
| `clipboardWriteFailed` | NSPasteboard write failure |

### Pasteboard Types

Writes both:
- `NSPasteboard.PasteboardType.png` (primary)
- `NSPasteboard.PasteboardType.tiff` (compatibility)

---

## 4. HotkeyService

Registers and manages global keyboard shortcuts.

### Protocol

```swift
protocol HotkeyServiceProtocol: Sendable {
    /// Register a global hotkey
    func register(
        keyCode: UInt32,
        modifiers: NSEvent.ModifierFlags,
        action: @escaping @Sendable () -> Void
    ) async throws -> HotkeyRegistration

    /// Unregister a hotkey
    func unregister(_ registration: HotkeyRegistration) async

    /// Check if key combination conflicts with system
    func checkConflict(
        keyCode: UInt32,
        modifiers: NSEvent.ModifierFlags
    ) async -> HotkeyConflict?
}

struct HotkeyRegistration: Sendable {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags
}

struct HotkeyConflict: Sendable {
    let existingApp: String?
    let isSystemShortcut: Bool
}
```

### Errors

| Error | When |
|-------|------|
| `hotkeyRegistrationFailed` | Carbon API returned error |
| `hotkeyConflict` | Key combo already in use |

---

## 5. SettingsService

Persists and retrieves user preferences.

### Protocol

```swift
protocol SettingsServiceProtocol: Sendable {
    /// Current settings (observable)
    var settings: AppSettings { get async }

    /// Update settings
    func update(_ settings: AppSettings) async

    /// Reset to defaults
    func resetToDefaults() async

    /// Add to recent captures
    func addRecentCapture(_ capture: RecentCapture) async

    /// Get recent captures
    var recentCaptures: [RecentCapture] { get async }
}
```

### Persistence Keys

| Key | Type | Default |
|-----|------|---------|
| `ScreenCapture.saveLocation` | URL | ~/Desktop |
| `ScreenCapture.defaultFormat` | String | "png" |
| `ScreenCapture.jpegQuality` | Double | 0.9 |
| `ScreenCapture.fullScreenShortcut` | Data | ⌘⇧3 encoded |
| `ScreenCapture.selectionShortcut` | Data | ⌘⇧4 encoded |
| `ScreenCapture.strokeColor` | Data | red encoded |
| `ScreenCapture.strokeWidth` | Double | 2.0 |
| `ScreenCapture.textSize` | Double | 14.0 |
| `ScreenCapture.recentCaptures` | Data | [] encoded |

---

## 6. RecentCapturesStore

Specialized store for recent captures with thumbnails.

### Protocol

```swift
protocol RecentCapturesStoreProtocol: Sendable {
    /// All recent captures (newest first)
    var captures: [RecentCapture] { get async }

    /// Add new capture (auto-generates thumbnail)
    func add(filePath: URL, image: CGImage, date: Date) async

    /// Remove capture (e.g., file deleted)
    func remove(at index: Int) async

    /// Clear all recent captures
    func clear() async

    /// Stream of updates for UI binding
    var capturesStream: AsyncStream<[RecentCapture]> { get }
}
```

### Thumbnail Generation

- Max dimension: 128px
- Format: JPEG at 0.7 quality
- Max size: 10KB per thumbnail

---

## 7. AnnotationRenderer

Composites annotations onto captured image.

### Protocol

```swift
protocol AnnotationRendererProtocol: Sendable {
    /// Render annotations onto image
    func render(
        annotations: [Annotation],
        onto image: CGImage
    ) async -> CGImage

    /// Render single annotation for preview
    func renderPreview(
        annotation: Annotation,
        onto context: CGContext,
        scale: CGFloat
    )
}
```

### Rendering Order

1. Base image
2. Freehand annotations (in order added)
3. Rectangle annotations (in order added)
4. Text annotations (in order added)

---

## Service Dependencies

```
┌─────────────────────┐
│   PreviewViewModel  │
└─────────────────────┘
         │
         ├──▶ ImageExportService
         ├──▶ ClipboardService
         └──▶ AnnotationRenderer

┌─────────────────────┐
│   CaptureManager    │
└─────────────────────┘
         │
         └──▶ CaptureService

┌─────────────────────┐
│ MenuBarController   │
└─────────────────────┘
         │
         ├──▶ HotkeyService
         ├──▶ SettingsService
         └──▶ RecentCapturesStore

┌─────────────────────┐
│  SettingsViewModel  │
└─────────────────────┘
         │
         ├──▶ SettingsService
         └──▶ HotkeyService
```

---

## Testing Strategy

All protocols enable mock injection:

```swift
final class MockCaptureService: CaptureServiceProtocol {
    var mockDisplays: [DisplayInfo] = []
    var mockImage: CGImage?

    func captureFullScreen(display: DisplayInfo) async throws -> CGImage {
        guard let image = mockImage else {
            throw ScreenCaptureError.captureFailure(underlying: TestError.noMock)
        }
        return image
    }
    // ...
}
```

Unit tests verify ViewModels against mock services.
Integration tests verify services against real system APIs.
