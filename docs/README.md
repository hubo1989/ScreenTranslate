# ScreenTranslate Documentation

Welcome to the ScreenTranslate documentation. ScreenTranslate is a macOS menu bar application for capturing, annotating, and translating screenshots.

## Overview

ScreenTranslate provides:
- **Full-screen capture** - Capture entire displays with a single hotkey
- **Region selection** - Draw a selection rectangle to capture specific areas
- **Translation mode** - OCR and translate captured text instantly
- **Text selection translation** - Select text anywhere and translate
- **Annotation tools** - Add rectangles, arrows, freehand drawings, and text
- **Quick export** - Save to disk or copy to clipboard with keyboard shortcuts
- **Multi-monitor support** - Works seamlessly with multiple connected displays
- **Multi-engine translation** - Support for Apple Translation, LLM APIs, and self-hosted engines

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
- Accessibility permission (for text translation features)

### Installation

Download the latest DMG from the [Releases](https://github.com/hubo1989/ScreenTranslate/releases) page.

### Default Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+3` | Capture full screen |
| `Cmd+Shift+4` | Capture selection |
| `Cmd+Shift+T` | Translation mode |
| `Cmd+Shift+Y` | Text selection translation |
| `Cmd+Shift+I` | Translate and insert |
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

- **Swift 6.0** with strict concurrency checking
- **SwiftUI** for modern UI components
- **AppKit** for menu bar integration and native windows
- **ScreenCaptureKit** for system-level screenshot capture
- **Vision** for Apple native OCR
- **Translation** for Apple system translation
- **CoreGraphics** for image manipulation

## Project Structure

```
ScreenTranslate/
├── App/                    # Application entry point
├── Features/               # Feature modules
│   ├── Capture/           # Screenshot capture logic
│   ├── Preview/           # Post-capture editing
│   ├── Annotations/       # Drawing tools
│   ├── TextTranslation/   # Text selection translation
│   ├── Settings/          # Preferences UI
│   └── MenuBar/           # Status bar integration
├── Services/              # Reusable services
│   ├── OCREngine/         # OCR providers
│   └── Translation/       # Translation providers
├── Models/                # Data types
├── Extensions/            # Swift extensions
└── Resources/             # Assets
```

## License

This project is licensed under the **MIT License** - see the [LICENSE](../LICENSE) file for details.
