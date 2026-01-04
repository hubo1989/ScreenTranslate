# Developer Guide

This guide covers setup, building, testing, and contributing to ScreenCapture.

## Prerequisites

- **macOS 13.0** (Ventura) or later
- **Xcode 15.0** or later
- **Swift 6.2.3** (included with Xcode)
- Apple Developer account (for signing and notarization)

## Getting Started

### Clone the Repository

```bash
git clone <repository-url>
cd edashot
```

### Open in Xcode

```bash
open ScreenCapture.xcodeproj
```

### First Build

1. Select the `ScreenCapture` scheme
2. Choose your Mac as the run destination
3. Press `Cmd+R` to build and run

### Permissions

On first launch, you'll be prompted for **Screen Recording** permission. Grant this in:

```
System Settings → Privacy & Security → Screen Recording
```

## Project Structure

```
ScreenCapture/
├── App/
│   ├── ScreenCaptureApp.swift     # @main entry point
│   └── AppDelegate.swift          # Lifecycle management
│
├── Features/
│   ├── Capture/
│   │   ├── CaptureManager.swift   # Screenshot capture
│   │   ├── ScreenDetector.swift   # Display enumeration
│   │   ├── SelectionOverlay*.swift # Region selection UI
│   │   └── DisplaySelector.swift  # Multi-monitor support
│   │
│   ├── Preview/
│   │   ├── PreviewWindow.swift    # Preview NSPanel
│   │   ├── PreviewViewModel.swift # State management
│   │   ├── PreviewContentView.swift # SwiftUI content
│   │   └── AnnotationCanvas.swift # Drawing surface
│   │
│   ├── Annotations/
│   │   ├── Annotation.swift       # Annotation enum
│   │   ├── AnnotationTool.swift   # Tool protocol
│   │   ├── RectangleTool.swift
│   │   ├── FreehandTool.swift
│   │   ├── ArrowTool.swift
│   │   └── TextTool.swift
│   │
│   ├── MenuBar/
│   │   └── MenuBarController.swift # Status item & menu
│   │
│   └── Settings/
│       ├── SettingsView.swift     # Preferences UI
│       ├── SettingsViewModel.swift
│       └── SettingsWindowController.swift
│
├── Services/
│   ├── ImageExporter.swift        # File export
│   ├── ClipboardService.swift     # Pasteboard operations
│   ├── HotkeyManager.swift        # Global shortcuts
│   └── RecentCapturesStore.swift  # Recent captures
│
├── Models/
│   ├── Screenshot.swift           # Screenshot data
│   ├── DisplayInfo.swift          # Display metadata
│   ├── AppSettings.swift          # Preferences
│   ├── ExportFormat.swift         # PNG/JPEG
│   ├── KeyboardShortcut.swift     # Hotkey representation
│   └── Styles.swift               # StrokeStyle, TextStyle
│
├── Extensions/
│   ├── CGImage+Extensions.swift   # Image utilities
│   ├── NSImage+Extensions.swift
│   └── View+Cursor.swift
│
├── Errors/
│   └── ScreenCaptureError.swift   # Error types
│
└── Resources/
    └── Assets.xcassets            # App icons, colors
```

## Build Configuration

### Swift Settings

The project uses **Swift 6.2.3** with strict concurrency checking:

```swift
// Build Settings
SWIFT_VERSION = 6.2.3
SWIFT_STRICT_CONCURRENCY = complete
```

### Deployment Target

- Minimum: macOS 13.0
- Recommended: macOS 14.0+

### Entitlements

Required capabilities in `ScreenCapture.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

**Note:** The app currently runs without sandboxing due to Carbon hotkey APIs. Future versions may migrate to CGEventTap for sandbox compatibility.

## Code Style

### Swift Conventions

- Use `final class` for non-inheritable classes
- Prefer `struct` for value types
- Use `actor` for thread-safe singletons
- Mark UI code with `@MainActor`

### Naming

- Types: `PascalCase`
- Functions/Properties: `camelCase`
- Constants: `camelCase`
- Acronyms: `URL`, `ID` (uppercase in type position)

### File Organization

Each file should contain:
1. Import statements
2. Type declaration
3. Properties
4. Initializers
5. Public methods
6. Private methods
7. Extensions (if small)

### Documentation

Use DocC-style comments for public APIs:

```swift
/// Captures the full contents of a display.
///
/// - Parameter display: The display to capture
/// - Returns: A screenshot containing the captured image
/// - Throws: `ScreenCaptureError` if capture fails
func captureFullScreen(display: DisplayInfo) async throws -> Screenshot
```

## Common Tasks

### Adding a New Annotation Tool

1. **Create the tool struct:**

```swift
// Features/Annotations/HighlightTool.swift
struct HighlightTool: AnnotationTool {
    private var state = DrawingState()
    private var style: StrokeStyle = .init(color: .yellow, lineWidth: 20)

    var currentAnnotation: Annotation? {
        guard state.isDrawing else { return nil }
        // Build preview annotation
    }

    mutating func beginDrawing(at point: CGPoint, style: StrokeStyle) {
        self.style = style
        state = DrawingState(startPoint: point, points: [point], isDrawing: true)
    }

    mutating func continueDrawing(to point: CGPoint) {
        guard state.isDrawing else { return }
        state.points.append(point)
    }

    mutating func endDrawing(at point: CGPoint) -> Annotation? {
        guard state.isDrawing else { return nil }
        // Create final annotation
    }

    mutating func cancelDrawing() {
        state = DrawingState()
    }
}
```

2. **Add annotation case:**

```swift
// Models/Annotation.swift
enum Annotation {
    case rectangle(RectangleAnnotation)
    case freehand(FreehandAnnotation)
    case arrow(ArrowAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)  // New
}
```

3. **Add tool type:**

```swift
// Features/Annotations/AnnotationToolType.swift
enum AnnotationToolType {
    case rectangle
    case freehand
    case arrow
    case text
    case highlight  // New
}
```

4. **Update PreviewViewModel:**

```swift
// Features/Preview/PreviewViewModel.swift
private var highlightTool = HighlightTool()

// In selectTool(_:)
case .highlight:
    // Configure tool
```

5. **Add keyboard shortcut:**

```swift
// Features/Preview/PreviewWindow.swift
case "H", "5":
    viewModel.selectTool(.highlight)
```

6. **Add toolbar button in PreviewContentView**

### Adding a New Export Format

1. **Extend ExportFormat:**

```swift
enum ExportFormat: String, Codable {
    case png
    case jpeg
    case webp  // New
}
```

2. **Add properties:**

```swift
var uti: UTType {
    switch self {
    case .webp: return .webP
    // ...
    }
}
```

3. **Update ImageExporter to handle encoding**

### Adding a New Setting

1. **Add property to AppSettings:**

```swift
@Observable
class AppSettings {
    var newSetting: Bool {
        didSet { UserDefaults.standard.set(newSetting, forKey: "newSetting") }
    }
}
```

2. **Add default in initializer:**

```swift
init() {
    self.newSetting = UserDefaults.standard.bool(forKey: "newSetting")
}
```

3. **Add to resetToDefaults():**

```swift
func resetToDefaults() {
    newSetting = false
    // ...
}
```

4. **Add UI in SettingsView**

## Debugging

### Enable Verbose Logging

Add `OSLog` statements with categories:

```swift
import os.log

private let logger = Logger(subsystem: "com.app.ScreenCapture", category: "Capture")

func captureFullScreen(display: DisplayInfo) async throws -> Screenshot {
    logger.info("Starting capture for display: \(display.name)")
    // ...
    logger.debug("Capture completed in \(elapsed)ms")
}
```

### Performance Profiling

The capture system uses OSSignpost for Instruments:

```swift
import os.signpost

let signpostID = OSSignpostID(log: .default)
os_signpost(.begin, log: .default, name: "ScreenCapture", signpostID: signpostID)
// ... capture operation
os_signpost(.end, log: .default, name: "ScreenCapture", signpostID: signpostID)
```

Open in Instruments → Points of Interest to view timing.

### Common Issues

**Permission Denied:**
- Check Screen Recording permission in System Settings
- Restart app after granting permission

**Hotkeys Not Working:**
- Check for conflicts with other apps
- Verify modifiers include Cmd, Ctrl, or Opt

**Blank Captures:**
- Display may be disconnected
- Check display scale factor

## Testing

### Unit Tests

```bash
xcodebuild test \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS'
```

### Manual Testing Checklist

- [ ] Full screen capture on primary display
- [ ] Full screen capture on secondary display
- [ ] Selection capture
- [ ] All annotation tools
- [ ] Undo/redo
- [ ] Crop mode
- [ ] Save to disk
- [ ] Copy to clipboard
- [ ] Settings persistence
- [ ] Hotkey registration
- [ ] Menu bar functionality

## Building for Release

### Archive

```bash
xcodebuild archive \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -archivePath build/ScreenCapture.xcarchive
```

### Export

```bash
xcodebuild -exportArchive \
  -archivePath build/ScreenCapture.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

### Notarization

```bash
xcrun notarytool submit build/export/ScreenCapture.app.zip \
  --apple-id "developer@example.com" \
  --team-id "TEAMID" \
  --password "@keychain:AC_PASSWORD" \
  --wait
```

## Contributing

### Workflow

1. Create a feature branch from `main`
2. Make changes with clear commits
3. Run tests and verify manually
4. Create pull request with description
5. Address review feedback
6. Squash and merge

### Commit Messages

```
feat: Add highlight annotation tool

- Implement HighlightTool conforming to AnnotationTool
- Add highlight case to Annotation enum
- Add keyboard shortcut (H/5)
- Update toolbar with highlight button
```

Prefixes:
- `feat:` New feature
- `fix:` Bug fix
- `refactor:` Code restructuring
- `docs:` Documentation
- `test:` Test changes
- `chore:` Build/config changes

### Code Review Guidelines

- Ensure Swift 6 concurrency safety
- Check for memory leaks
- Verify error handling
- Test on multiple displays
- Check Retina/non-Retina rendering
