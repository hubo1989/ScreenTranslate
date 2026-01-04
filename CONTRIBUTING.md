# Contributing to ScreenCapture

Thank you for your interest in contributing to ScreenCapture! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

**When reporting bugs, include:**
- macOS version
- ScreenCapture version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable
- Console logs if available

### Suggesting Features

Feature requests are welcome! Please:
- Check existing issues/discussions first
- Describe the use case clearly
- Explain why existing features don't solve it

### Pull Requests

1. **Fork** the repository
2. **Clone** your fork locally
3. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes** following our code style
5. **Test** your changes thoroughly
6. **Commit** with clear messages:
   ```bash
   git commit -m "feat: Add new annotation tool"
   ```
7. **Push** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
8. **Open a Pull Request** against `main`

## Development Setup

### Prerequisites

- macOS 13.0+
- Xcode 15.0+
- Swift 6.2+

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/ScreenCapture.git
cd ScreenCapture

# Open in Xcode
open ScreenCapture.xcodeproj

# Build and run
# Press Cmd+R in Xcode
```

### Granting Permissions

On first run, grant **Screen Recording** permission:
1. System Settings → Privacy & Security → Screen Recording
2. Enable ScreenCapture
3. Restart the app

## Code Style

### Swift Guidelines

- Use Swift 6.2 features appropriately
- Enable strict concurrency checking
- Mark UI code with `@MainActor`
- Use `actor` for thread-safe singletons
- Prefer `struct` over `class` for value types
- Use `final class` when inheritance isn't needed

### Naming Conventions

- Types: `PascalCase`
- Functions/properties: `camelCase`
- File names match type names

### Documentation

- Document public APIs with DocC-style comments
- Include parameter descriptions
- Document thrown errors

```swift
/// Captures the entire display.
///
/// - Parameter display: The display to capture
/// - Returns: Screenshot with captured image
/// - Throws: `ScreenCaptureError.permissionDenied` if access denied
func captureFullScreen(display: DisplayInfo) async throws -> Screenshot
```

## Commit Messages

Use conventional commits:

| Prefix | Description |
|--------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `refactor:` | Code restructuring |
| `test:` | Test changes |
| `chore:` | Build/config changes |

Examples:
```
feat: Add highlight annotation tool
fix: Correct selection overlay on Retina displays
docs: Update API reference for CaptureManager
refactor: Extract common drawing logic
```

## Testing

### Manual Testing Checklist

Before submitting a PR, verify:

- [ ] Full screen capture works
- [ ] Selection capture works
- [ ] All annotation tools function
- [ ] Undo/redo works correctly
- [ ] Save to disk succeeds
- [ ] Copy to clipboard works
- [ ] Settings persist correctly
- [ ] Multi-monitor support works
- [ ] No memory leaks (check Instruments)

### Running Tests

```bash
xcodebuild test \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS'
```

## Project Structure

```
ScreenCapture/
├── App/                # Entry point, AppDelegate
├── Features/           # Feature modules
│   ├── Capture/       # Screenshot capture
│   ├── Preview/       # Preview window
│   ├── Annotations/   # Drawing tools
│   ├── MenuBar/       # Status bar
│   └── Settings/      # Preferences
├── Services/          # Business logic
├── Models/            # Data types
├── Extensions/        # Swift extensions
└── Errors/            # Error types
```

## Adding Features

### New Annotation Tool

1. Create tool in `Features/Annotations/`
2. Conform to `AnnotationTool` protocol
3. Add case to `Annotation` enum
4. Add to `AnnotationToolType`
5. Update `PreviewViewModel`
6. Add keyboard shortcut
7. Add toolbar button

### New Export Format

1. Add case to `ExportFormat`
2. Implement encoding in `ImageExporter`
3. Update settings UI

See [Developer Guide](./docs/developer-guide.md) for detailed instructions.

## Review Process

1. PRs require at least one approval
2. All CI checks must pass
3. Code must follow style guidelines
4. Changes must be tested
5. Documentation must be updated

## Questions?

- Open a [Discussion](../../discussions) for questions
- Check existing [Issues](../../issues)
- Read the [Documentation](./docs)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing!
