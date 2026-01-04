# Components

This document provides detailed documentation for each major component and feature in ScreenCapture.

## Application Layer

### ScreenCaptureApp

**Location:** `ScreenCapture/App/ScreenCaptureApp.swift`

The main entry point using SwiftUI's `@main` attribute. Configures the application delegate and provides an empty Settings scene (settings are managed via a custom window).

```swift
@main
struct ScreenCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { }
    }
}
```

### AppDelegate

**Location:** `ScreenCapture/App/AppDelegate.swift`

The central coordinator managing application lifecycle, hotkeys, and capture actions.

**Responsibilities:**
- Application lifecycle management
- Global hotkey registration/unregistration
- Screen recording permission handling
- Capture action coordination
- Error presentation

**Key Methods:**

| Method | Description |
|--------|-------------|
| `applicationDidFinishLaunching(_:)` | Initializes menu bar, hotkeys, permissions |
| `applicationWillTerminate(_:)` | Cleanup resources |
| `captureFullScreen()` | Initiates full-screen capture |
| `captureSelection()` | Initiates selection capture |
| `showError(_:)` | Displays error dialogs |

---

## Capture System

### CaptureManager

**Location:** `ScreenCapture/Features/Capture/CaptureManager.swift`

Thread-safe singleton actor for all capture operations using ScreenCaptureKit.

**Key Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `shared` | `CaptureManager` | Singleton instance |

**Key Methods:**

| Method | Description |
|--------|-------------|
| `captureFullScreen(display:)` | Captures entire display |
| `captureRegion(_:from:)` | Captures specific region |
| `availableDisplays()` | Returns connected displays |
| `requestPermission()` | Triggers permission prompt |

**Performance:**
- Uses OSSignpost for latency monitoring
- Target: <50ms capture latency

**Example:**

```swift
let manager = CaptureManager.shared
let displays = try await manager.availableDisplays()

if let primaryDisplay = displays.first(where: { $0.isPrimary }) {
    let screenshot = try await manager.captureFullScreen(display: primaryDisplay)
}
```

### ScreenDetector

**Location:** `ScreenCapture/Features/Capture/ScreenDetector.swift`

Actor for display enumeration with caching.

**Features:**
- 5-second cache validity
- Matches SCDisplay with NSScreen
- Provides display metadata (resolution, scale, position)

### SelectionOverlayWindow

**Location:** `ScreenCapture/Features/Capture/SelectionOverlayWindow.swift`

NSPanel subclass providing the selection UI overlay.

**Features:**
- Borderless, floating panel
- Crosshair cursor tracking
- Dim effect layer
- Selection rectangle rendering
- Mouse event handling

**Delegate Protocol:**

```swift
protocol SelectionOverlayDelegate: AnyObject {
    func selectionCompleted(rect: CGRect, display: DisplayInfo)
    func selectionCancelled()
}
```

### DisplaySelector

**Location:** `ScreenCapture/Features/Capture/DisplaySelector.swift`

Helper for multi-monitor support. Presents a menu when multiple displays are connected.

---

## Preview System

### PreviewWindow

**Location:** `ScreenCapture/Features/Preview/PreviewWindow.swift`

NSPanel subclass for post-capture preview and annotation.

**Features:**
- Floating window level
- 400×300 minimum size
- SwiftUI hosting via NSHostingView
- Keyboard shortcut handling

**Keyboard Shortcuts:**

| Key | Action |
|-----|--------|
| `Escape` | Deselect annotation / Dismiss window |
| `Delete` / `Backspace` | Delete selected annotation |
| `Enter` / `Cmd+S` | Save screenshot |
| `Cmd+C` | Copy to clipboard and dismiss |
| `Cmd+Z` | Undo |
| `Shift+Cmd+Z` | Redo |
| `1` / `R` | Rectangle tool |
| `2` / `D` | Freehand tool |
| `3` / `A` | Arrow tool |
| `4` / `T` | Text tool |
| `C` | Toggle crop mode |

### PreviewViewModel

**Location:** `ScreenCapture/Features/Preview/PreviewViewModel.swift`

Central state management for preview window (~976 lines).

**State Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `screenshot` | `Screenshot` | Current image being previewed |
| `selectedTool` | `AnnotationToolType?` | Active annotation tool |
| `isCropMode` | `Bool` | Crop editing state |
| `annotations` | `[Annotation]` | Current annotations |
| `selectedAnnotationIndex` | `Int?` | Selected for editing |
| `errorMessage` | `String?` | Display error message |

**Drawing Methods:**

```swift
func beginDrawing(at point: CGPoint)
func continueDrawing(to point: CGPoint)
func endDrawing(at point: CGPoint)
```

**Annotation Editing:**

```swift
func selectAnnotation(at point: CGPoint) -> Bool
func beginDraggingAnnotation(at point: CGPoint)
func updateSelectedAnnotationColor(_ color: Color)
func deleteSelectedAnnotation()
```

**Undo/Redo:**
- Stack-based history (max 50 states)
- `undo()` and `redo()` methods

**Export:**

```swift
func copyToClipboard()
func saveScreenshot()
```

### PreviewContentView

**Location:** `ScreenCapture/Features/Preview/PreviewContentView.swift`

SwiftUI view displaying the image, annotations, and controls.

### AnnotationCanvas

**Location:** `ScreenCapture/Features/Preview/AnnotationCanvas.swift`

Custom SwiftUI canvas for rendering annotations with hit-testing.

---

## Annotation System

### Annotation (Enum)

**Location:** `ScreenCapture/Features/Annotations/Annotation.swift`

Tagged enum representing all annotation types.

**Cases:**

| Case | Description |
|------|-------------|
| `.rectangle(RectangleAnnotation)` | Rectangle/square shape |
| `.freehand(FreehandAnnotation)` | Freehand path |
| `.arrow(ArrowAnnotation)` | Arrow with head |
| `.text(TextAnnotation)` | Text label |

**Common Properties:**

```swift
var id: UUID
var bounds: CGRect
func contains(point: CGPoint) -> Bool
```

### AnnotationTool (Protocol)

**Location:** `ScreenCapture/Features/Annotations/AnnotationTool.swift`

Protocol defining tool interface.

```swift
protocol AnnotationTool {
    var currentAnnotation: Annotation? { get }

    mutating func beginDrawing(at point: CGPoint, style: StrokeStyle)
    mutating func continueDrawing(to point: CGPoint)
    mutating func endDrawing(at point: CGPoint) -> Annotation?
    mutating func cancelDrawing()
}
```

**DrawingState:**

```swift
struct DrawingState {
    var startPoint: CGPoint
    var points: [CGPoint]
    var isDrawing: Bool
}
```

### RectangleTool

**Location:** `ScreenCapture/Features/Annotations/RectangleTool.swift`

Draws rectangles by dragging opposite corners.

**Features:**
- Minimum 2px size validation
- Coordinate normalization
- Optional fill mode

### FreehandTool

**Location:** `ScreenCapture/Features/Annotations/FreehandTool.swift`

Freehand drawing with point decimation.

**Features:**
- Point decimation (≥2.0pt threshold)
- Minimum 2 points required
- Smooth path rendering

### ArrowTool

**Location:** `ScreenCapture/Features/Annotations/ArrowTool.swift`

Arrow from start to end point.

**Features:**
- Minimum 5pt length validation
- Arrowhead styling
- Bounds include padding

### TextTool

**Location:** `ScreenCapture/Features/Annotations/TextTool.swift`

Click to place, then type text.

**Features:**
- Two-phase: placement then editing
- Non-empty content validation
- Font customization

---

## Menu Bar

### MenuBarController

**Location:** `ScreenCapture/Features/MenuBar/MenuBarController.swift`

Manages the status bar icon and menu.

**Menu Structure:**

```
┌─────────────────────────────┐
│ Capture Full Screen  ⌘⇧3   │
│ Capture Selection    ⌘⇧4   │
├─────────────────────────────┤
│ Recent Captures        ▶   │
│   └─ Screenshot1.png       │
│   └─ Screenshot2.png       │
│   └─ Clear Recent          │
├─────────────────────────────┤
│ Settings...          ⌘,    │
├─────────────────────────────┤
│ Quit                 ⌘Q    │
└─────────────────────────────┘
```

**Status Item:**
- Uses SF Symbol: `camera.viewfinder`
- Click opens menu

---

## Settings

### SettingsView

**Location:** `ScreenCapture/Features/Settings/SettingsView.swift`

SwiftUI preferences interface.

**Sections:**
- Save Location
- Default Format (PNG/JPEG)
- JPEG Quality slider
- Keyboard Shortcuts
- Annotation defaults (color, stroke width, text size)

### SettingsViewModel

**Location:** `ScreenCapture/Features/Settings/SettingsViewModel.swift`

View model binding to AppSettings.

### SettingsWindowController

**Location:** `ScreenCapture/Features/Settings/SettingsWindowController.swift`

NSWindowController managing the settings window.

---

## Services

### ImageExporter

**Location:** `ScreenCapture/Services/ImageExporter.swift`

Exports screenshots with annotations to disk.

**Methods:**

```swift
func save(
    _ screenshot: Screenshot,
    annotations: [Annotation],
    to url: URL,
    format: ExportFormat,
    quality: Double
) throws

func generateFilename(format: ExportFormat) -> String
func generateFileURL(in directory: URL, format: ExportFormat) -> URL
```

**Validation:**
- Disk space check
- Directory writability
- Annotation compositing

### ClipboardService

**Location:** `ScreenCapture/Services/ClipboardService.swift`

Copies images to system pasteboard.

**Features:**
- Annotation compositing
- PNG + TIFF format support
- CGImage → NSImage conversion

**Methods:**

```swift
func copy(_ image: CGImage, annotations: [Annotation]) throws
var hasImage: Bool { get }
```

### HotkeyManager

**Location:** `ScreenCapture/Services/HotkeyManager.swift`

Global keyboard shortcut management using Carbon APIs.

**Features:**
- Uses `RegisterEventHotKey` API
- Sandboxing compatible
- Per-hotkey handlers

**Methods:**

```swift
func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32
func unregister(_ id: UInt32)
```

### RecentCapturesStore

**Location:** `ScreenCapture/Services/RecentCapturesStore.swift`

Manages recent captures list (max 5).

**Features:**
- Thumbnail generation (128px max, 10KB JPEG)
- Persistence via AppSettings
- File existence validation

**Methods:**

```swift
func add(filePath: URL, image: CGImage)
func remove(capture: RecentCapture)
func clear()
```

---

## Models

### Screenshot

**Location:** `ScreenCapture/Models/Screenshot.swift`

Immutable struct representing captured image.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `image` | `CGImage` | Raw pixels |
| `captureDate` | `Date` | When captured |
| `sourceDisplay` | `DisplayInfo` | Source display |
| `annotations` | `[Annotation]` | Drawing overlays |
| `filePath` | `URL?` | Saved location |
| `format` | `ExportFormat` | PNG/JPEG |

**Computed Properties:**

```swift
var dimensions: CGSize
var formattedDimensions: String
var estimatedFileSize: Int
var aspectRatio: CGFloat
var isSaved: Bool
var hasAnnotations: Bool
```

**Methods:**

```swift
func adding(_ annotation: Annotation) -> Screenshot
func replacingAnnotation(at index: Int, with: Annotation) -> Screenshot
func removingAnnotation(at index: Int) -> Screenshot
func generateThumbnail(maxSize: CGFloat) -> CGImage?
```

### DisplayInfo

**Location:** `ScreenCapture/Models/DisplayInfo.swift`

Immutable value type for connected displays.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | `CGDirectDisplayID` | System identifier |
| `name` | `String` | User-visible name |
| `frame` | `CGRect` | Position/size in points |
| `scaleFactor` | `CGFloat` | Retina scale (1.0-3.0) |
| `isPrimary` | `Bool` | Main display flag |

**Computed Properties:**

```swift
var resolution: String  // "3456 × 2234"
var isRetina: Bool
var pixelSize: CGSize
var matchingScreen: NSScreen?
```

### AppSettings

**Location:** `ScreenCapture/Models/AppSettings.swift`

Persistent user preferences (~278 lines).

**Persistence:** UserDefaults with immediate save on change.

**Properties:**

| Property | Type | Default |
|----------|------|---------|
| `saveLocation` | `URL` | ~/Desktop |
| `defaultFormat` | `ExportFormat` | .png |
| `jpegQuality` | `Double` | 0.9 |
| `fullScreenShortcut` | `KeyboardShortcut` | Cmd+Shift+3 |
| `selectionShortcut` | `KeyboardShortcut` | Cmd+Shift+4 |
| `strokeColor` | `CodableColor` | .red |
| `strokeWidth` | `CGFloat` | 2.0 |
| `textSize` | `CGFloat` | 16.0 |
| `rectangleFilled` | `Bool` | false |
| `recentCaptures` | `[RecentCapture]` | [] |

**Methods:**

```swift
func resetToDefaults()
func addRecentCapture(_:)
func clearRecentCaptures()
```

### ExportFormat

**Location:** `ScreenCapture/Models/ExportFormat.swift`

Export format enumeration.

**Cases:**
- `.png` - Lossless, larger files
- `.jpeg` - Lossy, smaller files

**Properties:**

```swift
var uti: UTType
var fileExtension: String
var mimeType: String
var estimatedBytesPerPixel: Double  // PNG: 1.5, JPEG: 0.3
var displayName: String
```

### KeyboardShortcut

**Location:** `ScreenCapture/Models/KeyboardShortcut.swift`

Keyboard shortcut representation.

**Properties:**

```swift
var keyCode: UInt32      // Carbon virtual key code
var modifiers: UInt32    // Carbon modifier flags
var displayString: String   // "Cmd+Shift+3"
var symbolString: String    // "⌘⇧3"
```

**Constants:**

```swift
static let fullScreenDefault: KeyboardShortcut  // Cmd+Shift+3
static let selectionDefault: KeyboardShortcut   // Cmd+Shift+4
```

### Styles

**Location:** `ScreenCapture/Models/Styles.swift`

Styling types for annotations.

**StrokeStyle:**
```swift
struct StrokeStyle {
    var color: CodableColor
    var lineWidth: CGFloat  // 1.0-20.0pt
}
```

**TextStyle:**
```swift
struct TextStyle {
    var color: CodableColor
    var fontSize: CGFloat   // 8.0-72.0pt
    var fontName: String
}
```

**CodableColor:**
- Codable wrapper for SwiftUI Color
- RGB + alpha components
- Preset colors available

---

## Error Handling

### ScreenCaptureError

**Location:** `ScreenCapture/Errors/ScreenCaptureError.swift`

Comprehensive error enum with localization.

**Cases:**

| Case | Description |
|------|-------------|
| `permissionDenied` | Screen recording not allowed |
| `displayNotFound` | Display unavailable |
| `displayDisconnected` | Display removed |
| `captureFailure(underlying:)` | Low-level failure |
| `invalidSaveLocation` | Directory not writable |
| `diskFull` | No space available |
| `exportEncodingFailed` | Format encoding failure |
| `clipboardWriteFailed` | Pasteboard failure |
| `hotkeyRegistrationFailed` | Hotkey conflict |

All cases provide:
- `errorDescription: String?`
- `recoverySuggestion: String?`

---

## Extensions

### CGImage+Extensions

**Location:** `ScreenCapture/Extensions/CGImage+Extensions.swift`

Image manipulation utilities.

**Methods:**

```swift
func scaled(by factor: CGFloat) -> CGImage?
func resized(to size: CGSize) -> CGImage?
func cropped(to rect: CGRect) -> CGImage?
var pngData: Data?
func jpegData(quality: Double) -> Data?
var size: CGSize
var aspectRatio: CGFloat
```

### NSImage+Extensions

**Location:** `ScreenCapture/Extensions/NSImage+Extensions.swift`

NSImage helper methods.

### View+Cursor

**Location:** `ScreenCapture/Extensions/View+Cursor.swift`

SwiftUI cursor customization.
