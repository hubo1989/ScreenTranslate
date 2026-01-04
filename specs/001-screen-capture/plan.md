# Implementation Plan: ScreenCapture

**Branch**: `001-screen-capture` | **Date**: 2026-01-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-screen-capture/spec.md`

## Summary

Build a lightweight, native macOS screenshot application with full-screen and region
capture, annotation tools (rectangle, freehand, text), and a menu bar interface.
The app uses ScreenCaptureKit for modern multi-display capture, SwiftUI for preview
editing, and AppKit for system integration. Architecture follows MVVM with strict
Swift 6.2+ concurrency.

## Technical Context

**Language/Version**: Swift 6.2.3 with strict concurrency checking enabled
**Primary Dependencies**: ScreenCaptureKit, AppKit, SwiftUI, CoreGraphics, UniformTypeIdentifiers
**Storage**: UserDefaults for preferences; file system for screenshots
**Testing**: XCTest (unit + UI tests)
**Target Platform**: macOS 26.0+ (Tahoe), Apple Silicon (arm64)
**Project Type**: Single macOS application
**Performance Goals**: Capture <50ms, preview <100ms, 60fps annotation, <1% idle CPU
**Constraints**: Peak memory ≤2× image size, <1s launch time
**Scale/Scope**: Single-user utility app, ~20 Swift source files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Checkpoint | Status |
|-----------|------------|--------|
| I. Native macOS Design | Uses AppKit/SwiftUI native controls; follows HIG | ✓ |
| II. Swift 6.2+ Concurrency | Strict concurrency enabled; uses async/await, actors | ✓ |
| III. Minimal Friction UX | Primary workflow ≤3 steps; immediate feedback <100ms | ✓ |
| IV. Real-time Performance | Capture <50ms; frame latency <16ms; idle CPU <1% | ✓ |
| V. Memory Efficiency | Peak memory ≤2× image size; buffers released promptly | ✓ |
| VI. Accessibility | VoiceOver labels; keyboard nav; Reduce Motion support | ✓ |
| VII. Multi-display | Dynamic display detection; per-display capture; mixed DPI | ✓ |
| VIII. MVVM Architecture | Views → ViewModels → Models; no UI imports in VMs | ✓ |
| IX. Error Handling | Typed errors; user-friendly messages; graceful degradation | ✓ |

**Gate Status**: PASSED - All principles addressed in design.

## Project Structure

### Documentation (this feature)

```text
specs/001-screen-capture/
├── plan.md              # This file
├── research.md          # Phase 0: Technology research
├── data-model.md        # Phase 1: Entity definitions
├── quickstart.md        # Phase 1: Build and run guide
├── contracts/           # Phase 1: Internal API contracts
└── tasks.md             # Phase 2: Implementation tasks
```

### Source Code (repository root)

```text
ScreenCapture/
├── App/
│   ├── ScreenCaptureApp.swift       # @main entry, SwiftUI App lifecycle
│   └── AppDelegate.swift            # NSApplicationDelegate for menu bar
├── Features/
│   ├── Capture/
│   │   ├── CaptureManager.swift     # ScreenCaptureKit integration
│   │   ├── SelectionOverlayWindow.swift  # NSPanel for region selection
│   │   └── ScreenDetector.swift     # Multi-display enumeration
│   ├── Preview/
│   │   ├── PreviewWindow.swift      # NSPanel hosting SwiftUI
│   │   ├── PreviewViewModel.swift   # Annotation state, undo stack
│   │   └── AnnotationCanvas.swift   # SwiftUI Canvas for drawing
│   ├── Annotations/
│   │   ├── AnnotationTool.swift     # Protocol for all tools
│   │   ├── RectangleTool.swift      # Rectangle drawing
│   │   ├── FreehandTool.swift       # Freehand path drawing
│   │   └── TextTool.swift           # Text placement
│   ├── MenuBar/
│   │   ├── MenuBarController.swift  # NSStatusItem management
│   │   └── StatusItemView.swift     # Menu construction
│   └── Settings/
│       ├── SettingsView.swift       # SwiftUI settings UI
│       └── SettingsViewModel.swift  # Preferences binding
├── Services/
│   ├── ImageExporter.swift          # PNG/JPEG encoding
│   ├── ClipboardService.swift       # NSPasteboard integration
│   ├── HotkeyManager.swift          # Global shortcut registration
│   └── RecentCapturesStore.swift    # Last 5 captures tracking
├── Models/
│   ├── Screenshot.swift             # Capture data + metadata
│   ├── Annotation.swift             # Drawing element types
│   ├── DisplayInfo.swift            # Screen metadata
│   └── AppSettings.swift            # User preferences
├── Errors/
│   └── ScreenCaptureError.swift     # Typed error enum
├── Extensions/
│   ├── NSImage+Extensions.swift     # Image manipulation helpers
│   └── CGImage+Extensions.swift     # CoreGraphics utilities
├── Resources/
│   ├── Assets.xcassets              # App icon, menu bar icon
│   └── Localizable.strings          # User-facing strings
└── Supporting Files/
    ├── Info.plist                   # App configuration
    └── ScreenCapture.entitlements   # Sandbox + permissions
```

**Structure Decision**: Single macOS app with feature-based organization. AppKit for
system-level integration (menu bar, overlays), SwiftUI for editing UI. MVVM separation
maintained with ViewModels in Features/ and Services/ for shared functionality.

## Complexity Tracking

> No constitution violations. All complexity justified by requirements.

| Aspect | Justification |
|--------|---------------|
| Hybrid AppKit/SwiftUI | Required: NSStatusItem (menu bar), NSPanel (overlays) need AppKit; SwiftUI for modern editing UI |
| ScreenCaptureKit | Required: Modern multi-display capture API; CGWindowListCreateImage deprecated |
| Actor-based CaptureManager | Required: Thread-safe capture state management per Swift 6.2 concurrency |
