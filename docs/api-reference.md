# API Reference

This document provides a complete API reference for ScreenCapture's public interfaces, protocols, and data types.

## Table of Contents

- [CaptureManager](#capturemanager)
- [ScreenDetector](#screendetector)
- [PreviewViewModel](#previewviewmodel)
- [AnnotationTool Protocol](#annotationtool-protocol)
- [Models](#models)
- [Services](#services)
- [Errors](#errors)

---

## CaptureManager

Thread-safe singleton actor for screenshot capture operations.

```swift
actor CaptureManager {
    static let shared: CaptureManager
}
```

### Methods

#### captureFullScreen(display:)

Captures the entire contents of a display.

```swift
func captureFullScreen(display: DisplayInfo) async throws -> Screenshot
```

**Parameters:**
- `display`: The display to capture

**Returns:** A `Screenshot` containing the captured image and metadata

**Throws:** `ScreenCaptureError` on failure

**Example:**

```swift
let screenshot = try await CaptureManager.shared.captureFullScreen(display: display)
```

---

#### captureRegion(_:from:)

Captures a specific region of a display.

```swift
func captureRegion(_ region: CGRect, from display: DisplayInfo) async throws -> Screenshot
```

**Parameters:**
- `region`: Rectangle in point coordinates
- `display`: The display containing the region

**Returns:** A `Screenshot` containing the captured region

**Throws:** `ScreenCaptureError` on failure

**Note:** The region is automatically converted to pixel coordinates using the display's scale factor.

---

#### availableDisplays()

Returns all connected displays.

```swift
func availableDisplays() async throws -> [DisplayInfo]
```

**Returns:** Array of `DisplayInfo` for each connected display

**Throws:** `ScreenCaptureError` if enumeration fails

---

#### requestPermission()

Triggers the system screen recording permission prompt.

```swift
func requestPermission() async
```

---

## ScreenDetector

Actor for display enumeration with caching.

```swift
actor ScreenDetector {
    static let shared: ScreenDetector
}
```

### Methods

#### detectDisplays()

Returns all connected displays with optional caching.

```swift
func detectDisplays(useCache: Bool = true) async throws -> [DisplayInfo]
```

**Parameters:**
- `useCache`: Whether to use cached results (5-second validity)

**Returns:** Array of `DisplayInfo`

---

## PreviewViewModel

Observable class managing preview window state.

```swift
@Observable
@MainActor
final class PreviewViewModel {
    init(screenshot: Screenshot, settings: AppSettings)
}
```

### Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `screenshot` | `Screenshot` | get/set | Current image |
| `selectedTool` | `AnnotationToolType?` | get/set | Active tool |
| `isCropMode` | `Bool` | get/set | Crop editing state |
| `selectedAnnotationIndex` | `Int?` | get/set | Selected annotation |
| `errorMessage` | `String?` | get/set | Error to display |
| `canUndo` | `Bool` | get | Undo available |
| `canRedo` | `Bool` | get | Redo available |

### Drawing Methods

#### beginDrawing(at:)

Starts a new annotation at the given point.

```swift
func beginDrawing(at point: CGPoint)
```

**Requires:** `selectedTool` must be set

---

#### continueDrawing(to:)

Updates the current annotation with a new point.

```swift
func continueDrawing(to point: CGPoint)
```

---

#### endDrawing(at:)

Completes the current annotation.

```swift
func endDrawing(at point: CGPoint)
```

---

### Annotation Editing

#### selectAnnotation(at:)

Selects an annotation at the given point.

```swift
func selectAnnotation(at point: CGPoint) -> Bool
```

**Returns:** `true` if an annotation was selected

---

#### deleteSelectedAnnotation()

Removes the currently selected annotation.

```swift
func deleteSelectedAnnotation()
```

---

#### updateSelectedAnnotationColor(_:)

Changes the color of the selected annotation.

```swift
func updateSelectedAnnotationColor(_ color: Color)
```

---

### Undo/Redo

```swift
func undo()
func redo()
```

---

### Export

#### copyToClipboard()

Copies the screenshot with annotations to the system clipboard.

```swift
func copyToClipboard()
```

---

#### saveScreenshot()

Saves the screenshot with annotations to disk.

```swift
func saveScreenshot()
```

Uses settings from `AppSettings` for location and format.

---

## AnnotationTool Protocol

Protocol defining annotation tool behavior.

```swift
protocol AnnotationTool {
    var currentAnnotation: Annotation? { get }

    mutating func beginDrawing(at point: CGPoint, style: StrokeStyle)
    mutating func continueDrawing(to point: CGPoint)
    mutating func endDrawing(at point: CGPoint) -> Annotation?
    mutating func cancelDrawing()
}
```

### Implementations

| Type | Description |
|------|-------------|
| `RectangleTool` | Rectangle shapes |
| `FreehandTool` | Freehand paths |
| `ArrowTool` | Arrows with heads |
| `TextTool` | Text labels |

### DrawingState

State container for in-progress drawing.

```swift
struct DrawingState {
    var startPoint: CGPoint
    var points: [CGPoint]
    var isDrawing: Bool
}
```

---

## Models

### Screenshot

Immutable struct representing a captured screenshot.

```swift
struct Screenshot: Identifiable, Sendable {
    let id: UUID
    let image: CGImage
    let captureDate: Date
    let sourceDisplay: DisplayInfo
    var annotations: [Annotation]
    var filePath: URL?
    var format: ExportFormat
}
```

#### Computed Properties

```swift
var dimensions: CGSize { get }
var formattedDimensions: String { get }  // "1920 × 1080"
var estimatedFileSize: Int { get }
var formattedFileSize: String { get }    // "1.5 MB"
var aspectRatio: CGFloat { get }
var isSaved: Bool { get }
var hasAnnotations: Bool { get }
```

#### Methods

```swift
func adding(_ annotation: Annotation) -> Screenshot
func replacingAnnotation(at index: Int, with annotation: Annotation) -> Screenshot
func removingAnnotation(at index: Int) -> Screenshot
func generateThumbnail(maxSize: CGFloat) -> CGImage?
```

---

### DisplayInfo

Immutable value type for display information.

```swift
struct DisplayInfo: Identifiable, Hashable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let scaleFactor: CGFloat
    let isPrimary: Bool
}
```

#### Computed Properties

```swift
var resolution: String { get }     // "3456 × 2234"
var isRetina: Bool { get }
var pixelSize: CGSize { get }
var matchingScreen: NSScreen? { get }
```

---

### Annotation

Enum representing all annotation types.

```swift
enum Annotation: Identifiable, Equatable, Sendable {
    case rectangle(RectangleAnnotation)
    case freehand(FreehandAnnotation)
    case arrow(ArrowAnnotation)
    case text(TextAnnotation)
}
```

#### Common Properties

```swift
var id: UUID { get }
var bounds: CGRect { get }
func contains(point: CGPoint) -> Bool
```

---

### RectangleAnnotation

```swift
struct RectangleAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var origin: CGPoint
    var size: CGSize
    var style: StrokeStyle
    var isFilled: Bool
}
```

---

### FreehandAnnotation

```swift
struct FreehandAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var points: [CGPoint]
    var style: StrokeStyle
}
```

---

### ArrowAnnotation

```swift
struct ArrowAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var style: StrokeStyle
}
```

---

### TextAnnotation

```swift
struct TextAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var position: CGPoint
    var content: String
    var style: TextStyle
}
```

---

### ExportFormat

```swift
enum ExportFormat: String, Codable, CaseIterable {
    case png
    case jpeg
}
```

#### Properties

```swift
var uti: UTType { get }
var fileExtension: String { get }
var mimeType: String { get }
var estimatedBytesPerPixel: Double { get }
var displayName: String { get }
```

---

### KeyboardShortcut

```swift
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
}
```

#### Properties

```swift
var displayString: String { get }   // "Cmd+Shift+3"
var symbolString: String { get }    // "⌘⇧3"
var hasRequiredModifiers: Bool { get }
var isValid: Bool { get }
```

#### Constants

```swift
static let fullScreenDefault: KeyboardShortcut  // Cmd+Shift+3
static let selectionDefault: KeyboardShortcut   // Cmd+Shift+4
```

---

### StrokeStyle

```swift
struct StrokeStyle: Codable, Equatable {
    var color: CodableColor
    var lineWidth: CGFloat  // Range: 1.0-20.0
}
```

---

### TextStyle

```swift
struct TextStyle: Codable, Equatable {
    var color: CodableColor
    var fontSize: CGFloat   // Range: 8.0-72.0
    var fontName: String
}
```

---

### CodableColor

Codable wrapper for SwiftUI Color.

```swift
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}
```

#### Initializers

```swift
init(color: Color)
init(nsColor: NSColor)
init(red: Double, green: Double, blue: Double, alpha: Double = 1.0)
```

#### Conversions

```swift
var color: Color { get }
var nsColor: NSColor { get }
var cgColor: CGColor { get }
```

#### Presets

```swift
static let red: CodableColor
static let blue: CodableColor
static let green: CodableColor
static let yellow: CodableColor
static let orange: CodableColor
static let white: CodableColor
static let black: CodableColor
```

---

## Services

### ImageExporter

Service for exporting screenshots to disk.

```swift
struct ImageExporter {
    static func save(
        _ screenshot: Screenshot,
        annotations: [Annotation],
        to url: URL,
        format: ExportFormat,
        quality: Double
    ) throws

    static func generateFilename(format: ExportFormat) -> String
    static func generateFileURL(in directory: URL, format: ExportFormat) -> URL
}
```

---

### ClipboardService

Service for clipboard operations.

```swift
@MainActor
struct ClipboardService {
    static func copy(_ image: CGImage, annotations: [Annotation]) throws
    static var hasImage: Bool { get }
}
```

---

### HotkeyManager

Actor for global hotkey management.

```swift
actor HotkeyManager {
    static let shared: HotkeyManager

    func register(
        keyCode: UInt32,
        modifiers: UInt32,
        handler: @escaping () -> Void
    ) -> UInt32

    func unregister(_ id: UInt32)
}
```

---

### RecentCapturesStore

Store for managing recent captures.

```swift
@MainActor
@Observable
class RecentCapturesStore {
    static let shared: RecentCapturesStore

    var captures: [RecentCapture] { get }

    func add(filePath: URL, image: CGImage)
    func remove(capture: RecentCapture)
    func remove(at index: Int)
    func clear()
}
```

---

### AppSettings

Singleton for persistent user preferences.

```swift
@Observable
class AppSettings {
    static let shared: AppSettings

    var saveLocation: URL
    var defaultFormat: ExportFormat
    var jpegQuality: Double
    var fullScreenShortcut: KeyboardShortcut
    var selectionShortcut: KeyboardShortcut
    var strokeColor: CodableColor
    var strokeWidth: CGFloat
    var textSize: CGFloat
    var rectangleFilled: Bool
    var recentCaptures: [RecentCapture]

    func resetToDefaults()
    func addRecentCapture(_:)
    func clearRecentCaptures()
}
```

---

## Errors

### ScreenCaptureError

Comprehensive error enum with localization support.

```swift
enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case displayNotFound
    case displayDisconnected
    case captureFailure(underlying: Error)
    case invalidSaveLocation
    case diskFull
    case exportEncodingFailed
    case clipboardWriteFailed
    case hotkeyRegistrationFailed
    case hotkeyConflict(existingApp: String?)
}
```

#### LocalizedError Conformance

```swift
var errorDescription: String? { get }
var recoverySuggestion: String? { get }
```

---

## CGImage Extensions

```swift
extension CGImage {
    func scaled(by factor: CGFloat) -> CGImage?
    func resized(to size: CGSize) -> CGImage?
    func cropped(to rect: CGRect) -> CGImage?

    var pngData: Data? { get }
    func jpegData(quality: Double) -> Data?

    var size: CGSize { get }
    var aspectRatio: CGFloat { get }
}
```
