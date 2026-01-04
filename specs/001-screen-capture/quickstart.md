# Quickstart: ScreenCapture

**Branch**: `001-screen-capture` | **Date**: 2026-01-04
**Purpose**: Build and run instructions for development

## Prerequisites

| Requirement | Version | Check Command |
|-------------|---------|---------------|
| macOS | 26.0+ (Tahoe) | `sw_vers` |
| Xcode | 16.0+ | `xcodebuild -version` |
| Swift | 6.2.3+ | `swift --version` |
| Apple Silicon | arm64 | `uname -m` (should show `arm64`) |

## Quick Start

### 1. Clone and Open

```bash
git clone <repository-url>
cd edashot
open ScreenCapture.xcodeproj
```

### 2. Build and Run

```bash
# Build from command line
xcodebuild -scheme ScreenCapture -configuration Debug build

# Or use Xcode
# 1. Open ScreenCapture.xcodeproj
# 2. Select "My Mac" as destination
# 3. Press ⌘R to run
```

### 3. Grant Permissions

On first launch, macOS will prompt for screen recording permission:

1. Click "Open System Settings" when prompted
2. Navigate to Privacy & Security → Screen Recording
3. Toggle on "ScreenCapture"
4. Restart the app

## Project Structure

```
ScreenCapture/
├── ScreenCapture.xcodeproj    # Xcode project
├── ScreenCapture/             # Source code
│   ├── App/                   # Entry point
│   ├── Features/              # Feature modules
│   ├── Services/              # Business logic
│   ├── Models/                # Data types
│   └── Resources/             # Assets, strings
└── ScreenCaptureTests/        # Unit tests
```

## Build Configuration

### Debug Build

- Optimization: None (-Onone)
- Swift strict concurrency: Complete
- Assertions enabled

```bash
xcodebuild -scheme ScreenCapture -configuration Debug build
```

### Release Build

- Optimization: Whole module (-O -whole-module-optimization)
- Swift strict concurrency: Complete
- Strip debug symbols

```bash
xcodebuild -scheme ScreenCapture -configuration Release build
```

## Running Tests

### Unit Tests

```bash
xcodebuild test \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  -only-testing:ScreenCaptureTests
```

### UI Tests

```bash
xcodebuild test \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  -only-testing:ScreenCaptureUITests
```

## Development Workflow

### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/your-feature

# Build and test
xcodebuild -scheme ScreenCapture build test

# Commit changes
git add .
git commit -m "feat: description"
```

### 2. Code Style

Swift strict concurrency is enforced. Common patterns:

```swift
// Use @MainActor for UI code
@MainActor
class PreviewViewModel: ObservableObject { ... }

// Use actors for shared mutable state
actor CaptureManager { ... }

// Mark data types as Sendable
struct Screenshot: Sendable { ... }
```

### 3. Testing Services

Services are protocol-based for testability:

```swift
// In tests, inject mocks
let viewModel = PreviewViewModel(
    exportService: MockExportService(),
    clipboardService: MockClipboardService()
)
```

## Debugging

### Screen Capture Issues

1. Check permission in System Settings → Privacy → Screen Recording
2. Run in Debug mode to see console output
3. Use `SCShareableContent.getWithCompletionHandler` to enumerate displays

### Hotkey Issues

1. Check for conflicts in System Settings → Keyboard → Shortcuts
2. Run `defaults read com.apple.symbolichotkeys` to see system shortcuts
3. Try different key combinations

### Memory Issues

1. Profile with Instruments → Allocations
2. Check for CGImage leaks after capture
3. Verify thumbnails are properly downscaled

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SCREENCAPTURE_DEBUG` | Enable verbose logging | `0` |
| `SCREENCAPTURE_MOCK_DISPLAYS` | Use fake displays for testing | `0` |

Set in Xcode scheme or terminal:

```bash
SCREENCAPTURE_DEBUG=1 open ScreenCapture.app
```

## Entitlements

The app requires these entitlements (configured in `ScreenCapture.entitlements`):

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.app-sandbox` | App Store requirement |
| `com.apple.security.files.user-selected.read-write` | Save to user-selected folders |

Screen recording permission is granted at runtime via TCC prompt.

## Common Tasks

### Add New Annotation Tool

1. Create tool in `Features/Annotations/`
2. Conform to `AnnotationTool` protocol
3. Add case to `Annotation` enum in `Models/`
4. Update `AnnotationCanvas` rendering
5. Add keyboard shortcut in `PreviewViewModel`

### Change Default Settings

Edit `Models/AppSettings.swift` default values:

```swift
static let defaults = AppSettings(
    saveLocation: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!,
    defaultFormat: .png,
    jpegQuality: 0.9,
    // ...
)
```

### Add New Export Format

1. Add case to `ExportFormat` enum
2. Update `ImageExporter` to handle new format
3. Add option in `SettingsView`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Screen Recording" not appearing in System Settings | Restart the app after denying permission once |
| Hotkeys not working | Check System Settings → Keyboard → Shortcuts for conflicts |
| Build fails with concurrency errors | Ensure all shared types are `Sendable` |
| Memory usage too high | Check that `CGImage` references are released after save |

## Resources

- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [SwiftUI Canvas](https://developer.apple.com/documentation/swiftui/canvas)
- [AppKit NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [Constitution](/.specify/memory/constitution.md) - Project principles and guidelines
