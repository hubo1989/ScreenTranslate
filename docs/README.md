# ScreenCapture Documentation

Welcome to the ScreenCapture documentation. ScreenCapture is a macOS menu bar application for capturing and annotating screenshots.

## Overview

ScreenCapture provides:
- **Full-screen capture** - Capture entire displays with a single hotkey
- **Region selection** - Draw a selection rectangle to capture specific areas
- **Annotation tools** - Add rectangles, arrows, freehand drawings, and text
- **Quick export** - Save to disk or copy to clipboard with keyboard shortcuts
- **Multi-monitor support** - Works seamlessly with multiple connected displays

## Documentation Index

| Document | Description |
|----------|-------------|
| [Architecture](./architecture.md) | System design, patterns, and component relationships |
| [Components](./components.md) | Detailed documentation of each module and feature |
| [API Reference](./api-reference.md) | Public APIs, protocols, and data types |
| [Developer Guide](./developer-guide.md) | Setup, building, testing, and contributing |
| [User Guide](./user-guide.md) | Installation, usage, and keyboard shortcuts |

## Quick Start

### System Requirements

- macOS 13.0 (Ventura) or later
- Screen Recording permission (prompted on first launch)

### Default Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+3` | Capture full screen |
| `Cmd+Shift+4` | Capture selection |
| `Escape` | Cancel/dismiss |
| `Cmd+S` / `Enter` | Save screenshot |
| `Cmd+C` | Copy to clipboard |

### Annotation Tools (in Preview)

| Key | Tool |
|-----|------|
| `R` or `1` | Rectangle |
| `D` or `2` | Freehand drawing |
| `A` or `3` | Arrow |
| `T` or `4` | Text |
| `C` | Toggle crop mode |

## Technology Stack

- **Swift 6.2.3** with strict concurrency checking
- **SwiftUI** for modern UI components
- **AppKit** for menu bar integration and native windows
- **ScreenCaptureKit** for system-level screenshot capture
- **CoreGraphics** for image manipulation

## Project Structure

```
ScreenCapture/
├── App/                    # Application entry point
├── Features/               # Feature modules
│   ├── Capture/           # Screenshot capture logic
│   ├── Preview/           # Post-capture editing
│   ├── Annotations/       # Drawing tools
│   ├── MenuBar/           # Status bar integration
│   └── Settings/          # Preferences UI
├── Services/              # Reusable services
├── Models/                # Data types
├── Extensions/            # Swift extensions
├── Errors/                # Error types
└── Resources/             # Assets
```

## License

This project is licensed under the **MIT License** - see the [LICENSE](../LICENSE) file for details.

This means you are free to:
- Use the software for any purpose
- Modify the source code
- Distribute copies
- Include in commercial products

The only requirement is to include the original copyright notice and license text.
