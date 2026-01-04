# Data Model: ScreenCapture

**Branch**: `001-screen-capture` | **Date**: 2026-01-04
**Purpose**: Entity definitions derived from feature specification

## Entity Diagram

```
┌─────────────────┐     ┌─────────────────┐
│   Screenshot    │────▶│    Annotation   │ (1:N)
└─────────────────┘     └─────────────────┘
        │                       │
        │                       ▼
        │               ┌───────────────┐
        │               │  AnnotationType│
        │               │  - Rectangle  │
        │               │  - Freehand   │
        │               │  - Text       │
        │               └───────────────┘
        │
        ▼
┌─────────────────┐     ┌─────────────────┐
│   DisplayInfo   │     │   AppSettings   │
└─────────────────┘     └─────────────────┘
```

---

## 1. Screenshot

Represents a captured screen image with metadata.

### Fields

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | UUID | Unique identifier | Auto-generated |
| image | CGImage | Raw captured image data | Non-null |
| captureDate | Date | When capture occurred | Auto-set to now |
| sourceDisplay | DisplayInfo | Display from which captured | Non-null |
| dimensions | CGSize | Width × Height in pixels | Derived from image |
| annotations | [Annotation] | Drawing overlays | Initially empty |
| filePath | URL? | Saved file location | nil until saved |
| format | ExportFormat | PNG or JPEG | Default: PNG |

### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| estimatedFileSize | Int | Bytes estimate based on format and dimensions |
| aspectRatio | CGFloat | width / height |
| thumbnailImage | CGImage | Scaled-down preview (max 256px) |

### State Transitions

```
[Captured] ──(save)──▶ [Saved]
     │                    │
     │                    ├──(copy)──▶ [Copied to Clipboard]
     │                    │
     └──(dismiss)──▶ [Discarded]
```

---

## 2. Annotation

A drawing element placed on a screenshot.

### Enum Definition

```swift
enum Annotation: Identifiable, Equatable, Sendable {
    case rectangle(RectangleAnnotation)
    case freehand(FreehandAnnotation)
    case text(TextAnnotation)

    var id: UUID { /* derived from associated value */ }
}
```

### 2.1 RectangleAnnotation

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | UUID | Unique identifier | Auto-generated |
| rect | CGRect | Position and size in image coordinates | Non-empty |
| style | StrokeStyle | Color and line width | Non-null |

### 2.2 FreehandAnnotation

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | UUID | Unique identifier | Auto-generated |
| points | [CGPoint] | Path vertices in image coordinates | ≥2 points |
| style | StrokeStyle | Color and line width | Non-null |

### 2.3 TextAnnotation

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | UUID | Unique identifier | Auto-generated |
| position | CGPoint | Anchor point in image coordinates | Within bounds |
| content | String | User-entered text | Non-empty |
| style | TextStyle | Font, size, color | Non-null |

---

## 3. StrokeStyle

Styling for rectangle and freehand annotations.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| color | Color | Stroke color | .red |
| lineWidth | CGFloat | Stroke width in points | 2.0 |

### Validation Rules

- lineWidth: 1.0...20.0
- color: Any valid Color (user-selectable)

---

## 4. TextStyle

Styling for text annotations.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| color | Color | Text color | .red |
| fontSize | CGFloat | Font size in points | 14.0 |
| fontName | String | Font family | "SF Pro" (system) |

### Validation Rules

- fontSize: 8.0...72.0
- fontName: Must be available on system

---

## 5. DisplayInfo

Represents a connected display for capture targeting.

| Field | Type | Description | Source |
|-------|------|-------------|--------|
| id | CGDirectDisplayID | System display identifier | SCDisplay.displayID |
| name | String | User-visible display name | Derived |
| frame | CGRect | Position and size in global coordinates | SCDisplay |
| scaleFactor | CGFloat | Retina scale (1.0, 2.0, 3.0) | NSScreen |
| isPrimary | Bool | Whether this is the main display | NSScreen.main |

### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| resolution | String | "2560 × 1440" formatted |
| isRetina | Bool | scaleFactor > 1.0 |

---

## 6. AppSettings

User preferences persisted across sessions.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| saveLocation | URL | Default save directory | ~/Desktop |
| defaultFormat | ExportFormat | PNG or JPEG | .png |
| jpegQuality | Double | JPEG compression (0.0-1.0) | 0.9 |
| fullScreenShortcut | KeyboardShortcut | Global hotkey | ⌘⇧3 |
| selectionShortcut | KeyboardShortcut | Global hotkey | ⌘⇧4 |
| strokeColor | Color | Annotation default | .red |
| strokeWidth | CGFloat | Annotation default | 2.0 |
| textSize | CGFloat | Text annotation default | 14.0 |
| recentCaptures | [RecentCapture] | Last 5 saved | [] |

### Persistence

Stored in UserDefaults with keys prefixed `ScreenCapture.`.

---

## 7. ExportFormat

Supported image export formats.

```swift
enum ExportFormat: String, CaseIterable, Codable {
    case png
    case jpeg

    var uti: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }

    var fileExtension: String {
        rawValue
    }
}
```

---

## 8. KeyboardShortcut

Global hotkey configuration.

| Field | Type | Description |
|-------|------|-------------|
| keyCode | UInt32 | Virtual key code |
| modifiers | NSEvent.ModifierFlags | Cmd, Shift, Option, Control |

### Validation Rules

- Must include at least one modifier (Cmd, Ctrl, or Option)
- Cannot conflict with system shortcuts (warning shown)

---

## 9. RecentCapture

Entry in recent captures list.

| Field | Type | Description |
|-------|------|-------------|
| filePath | URL | Location of saved file |
| captureDate | Date | When captured |
| thumbnailData | Data | JPEG thumbnail (≤10KB) |

### Constraints

- Maximum 5 entries (FIFO)
- Thumbnails max 128px on longest edge

---

## 10. ScreenCaptureError

Typed error enum for all failure cases.

```swift
enum ScreenCaptureError: LocalizedError, Sendable {
    // Capture errors
    case permissionDenied
    case displayNotFound(CGDirectDisplayID)
    case captureFailure(underlying: Error)

    // Export errors
    case invalidSaveLocation(URL)
    case diskFull
    case exportEncodingFailed(format: ExportFormat)

    // Clipboard errors
    case clipboardWriteFailed

    // Hotkey errors
    case hotkeyRegistrationFailed(keyCode: UInt32)
    case hotkeyConflict(existingApp: String?)

    var errorDescription: String? { /* user-friendly message */ }
    var recoverySuggestion: String? { /* actionable next step */ }
}
```

---

## Relationships

| From | To | Cardinality | Description |
|------|-----|-------------|-------------|
| Screenshot | Annotation | 1:N | A screenshot has zero or more annotations |
| Screenshot | DisplayInfo | N:1 | Each screenshot is from one display |
| AppSettings | RecentCapture | 1:N | Settings track up to 5 recent captures |
| Annotation | StrokeStyle | 1:1 | Each shape annotation has styling |
| TextAnnotation | TextStyle | 1:1 | Each text annotation has styling |

---

## Thread Safety

All model types are `Sendable`:

- Screenshot, Annotation: Value types (struct/enum)
- DisplayInfo: Immutable after creation
- AppSettings: Accessed through `@MainActor` ViewModel
- ScreenCaptureError: Value type enum
