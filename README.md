<p align="center">
  <img src=".github/images/app-icon.png" alt="ScreenCapture" width="128" height="128">
</p>

<h1 align="center">ScreenCapture</h1>

<p align="center">
  A fast, lightweight macOS menu bar app for capturing and annotating screenshots.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13.0%2B-brightgreen.svg" alt="macOS"></a>
  <a href="https://swift.org/"><img src="https://img.shields.io/badge/Swift-6.2-orange.svg" alt="Swift"></a>
</p>

## Features

- **Instant Capture** - Full screen or region selection with global hotkeys
- **Annotation Tools** - Rectangles (filled/outline), arrows, freehand drawing, and text
- **Multi-Monitor Support** - Works seamlessly across all connected displays
- **Flexible Export** - PNG, JPEG, and HEIC formats with quality control
- **Crop & Edit** - Crop screenshots after capture with pixel-perfect precision
- **Quick Export** - Save to disk or copy to clipboard instantly
- **Lightweight** - Runs quietly in your menu bar with minimal resources

## Installation

### Requirements

- macOS 13.0 (Ventura) or later
- Screen Recording permission

### Download

Download the latest release from the [Releases](../../releases) page.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/sadopc/ScreenCapture.git
cd ScreenCapture

# Open in Xcode
open ScreenCapture.xcodeproj

# Build and run (Cmd+R)
```

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+3` | Capture full screen |
| `Cmd+Shift+4` | Capture selection |

### In Preview Window

| Shortcut | Action |
|----------|--------|
| `Enter` / `Cmd+S` | Save screenshot (or apply crop in crop mode) |
| `Cmd+C` | Copy to clipboard |
| `Escape` | Dismiss / Cancel crop / Deselect tool |
| `R` / `1` | Rectangle tool |
| `D` / `2` | Freehand tool |
| `A` / `3` | Arrow tool |
| `T` / `4` | Text tool |
| `C` | Crop mode |
| `Cmd+Z` | Undo |
| `Cmd+Shift+Z` | Redo |

## Documentation

Detailed documentation is available in the [docs](./docs) folder:

- [Architecture](./docs/architecture.md) - System design and patterns
- [Components](./docs/components.md) - Feature documentation
- [API Reference](./docs/api-reference.md) - Public APIs
- [Developer Guide](./docs/developer-guide.md) - Contributing guide
- [User Guide](./docs/user-guide.md) - End-user documentation

## Tech Stack

- **Swift 6.2** with strict concurrency
- **SwiftUI** + **AppKit** for native macOS UI
- **ScreenCaptureKit** for system-level capture
- **CoreGraphics** for image processing

## Contributing

Contributions are welcome! Please read our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_FORK/ScreenCapture.git

# Open in Xcode
open ScreenCapture.xcodeproj

# Grant Screen Recording permission when prompted
```

See the [Developer Guide](./docs/developer-guide.md) for detailed setup instructions.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License - Copyright (c) 2026 Serdar Albayrak
```

## Acknowledgments

- Built with [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- Icons from [SF Symbols](https://developer.apple.com/sf-symbols/)

---

Made with Swift for macOS
