# Tasks: ScreenCapture

**Input**: Design documents from `/specs/001-screen-capture/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in the feature specification. Test tasks are omitted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

macOS app structure per plan.md:

```text
ScreenCapture/
├── App/
├── Features/{Capture,Preview,Annotations,MenuBar,Settings}/
├── Services/
├── Models/
├── Errors/
├── Extensions/
├── Resources/
└── Supporting Files/
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Xcode project initialization and basic structure

- [x] T001 Create Xcode project ScreenCapture.xcodeproj with macOS App target, Swift 6.2.3, arm64
- [x] T002 Configure project for menu bar app (LSUIElement=true) in ScreenCapture/Supporting Files/Info.plist
- [x] T003 [P] Create entitlements file with App Sandbox and file access in ScreenCapture/Supporting Files/ScreenCapture.entitlements
- [x] T004 [P] Add Assets.xcassets with app icon and menu bar icon in ScreenCapture/Resources/Assets.xcassets
- [x] T005 [P] Create Localizable.strings with user-facing error messages in ScreenCapture/Resources/Localizable.strings
- [x] T006 Configure Swift strict concurrency (-strict-concurrency=complete) in build settings

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core models, errors, and app lifecycle that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T007 [P] Create ScreenCaptureError enum with all error cases in ScreenCapture/Errors/ScreenCaptureError.swift
- [x] T008 [P] Create ExportFormat enum (PNG/JPEG) in ScreenCapture/Models/ExportFormat.swift
- [x] T009 [P] Create DisplayInfo struct with SCDisplay mapping in ScreenCapture/Models/DisplayInfo.swift
- [x] T010 [P] Create Screenshot struct with metadata in ScreenCapture/Models/Screenshot.swift
- [x] T011 [P] Create StrokeStyle and TextStyle structs in ScreenCapture/Models/Styles.swift
- [x] T012 [P] Create KeyboardShortcut struct in ScreenCapture/Models/KeyboardShortcut.swift
- [x] T013 Create AppSettings struct with UserDefaults persistence in ScreenCapture/Models/AppSettings.swift
- [x] T014 [P] Create NSImage+Extensions for thumbnail generation in ScreenCapture/Extensions/NSImage+Extensions.swift
- [x] T015 [P] Create CGImage+Extensions for image utilities in ScreenCapture/Extensions/CGImage+Extensions.swift
- [x] T016 Create ScreenCaptureApp.swift with @main and AppDelegate setup in ScreenCapture/App/ScreenCaptureApp.swift
- [x] T017 Create AppDelegate.swift with NSApplicationDelegate skeleton in ScreenCapture/App/AppDelegate.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 5 - Menu Bar Interface (Priority: P1)

**Goal**: App runs as menu bar app with icon, menu, and hotkey registration

**Independent Test**: Click menu bar icon and verify menu opens with all items

### Implementation for User Story 5

- [x] T018 [US5] Create MenuBarController with NSStatusItem in ScreenCapture/Features/MenuBar/MenuBarController.swift
- [x] T019 [US5] Build NSMenu with Capture Full Screen, Capture Selection, Recent Captures, Settings, Quit in ScreenCapture/Features/MenuBar/MenuBarController.swift
- [x] T020 [US5] Create HotkeyManager actor with Carbon RegisterEventHotKey in ScreenCapture/Services/HotkeyManager.swift
- [x] T021 [US5] Register default hotkeys (⌘⇧3, ⌘⇧4) in AppDelegate on launch
- [x] T022 [US5] Create RecentCapturesStore with UserDefaults persistence in ScreenCapture/Services/RecentCapturesStore.swift
- [x] T023 [US5] Wire menu item actions to capture triggers in MenuBarController

**Checkpoint**: App launches to menu bar, menu opens, hotkeys registered (capture not yet functional)

---

## Phase 4: User Story 1 - Full Screen Capture (Priority: P1) 🎯 MVP

**Goal**: User presses hotkey → screen captured → preview window appears with image info

**Independent Test**: Press ⌘⇧3, verify full screen captured and preview shows dimensions

### Implementation for User Story 1

- [x] T024 [US1] Create ScreenDetector with SCShareableContent display enumeration in ScreenCapture/Features/Capture/ScreenDetector.swift
- [x] T025 [US1] Create CaptureManager actor with SCScreenshotManager.captureImage in ScreenCapture/Features/Capture/CaptureManager.swift
- [x] T026 [US1] Implement captureFullScreen(display:) with permission check in CaptureManager
- [x] T027 [US1] Add multi-display selection UI (NSMenu popup) when multiple displays in CaptureManager
- [x] T028 [US1] Create PreviewViewModel with @Observable for screenshot state in ScreenCapture/Features/Preview/PreviewViewModel.swift
- [x] T029 [US1] Create PreviewWindow NSPanel with floating level in ScreenCapture/Features/Preview/PreviewWindow.swift
- [x] T030 [US1] Create PreviewContentView SwiftUI with image display and info overlay in ScreenCapture/Features/Preview/PreviewContentView.swift
- [x] T031 [US1] Show dimensions and estimated file size in preview info bar
- [x] T032 [US1] Wire hotkey action → CaptureManager → PreviewWindow flow in AppDelegate

**Checkpoint**: Full screen capture works end-to-end; preview shows captured image with metadata

---

## Phase 5: User Story 2 - Partial Screen Selection (Priority: P1)

**Goal**: User presses hotkey → crosshair overlay → drag to select region → capture → preview

**Independent Test**: Press ⌘⇧4, drag rectangle, verify only selected region captured

### Implementation for User Story 2

- [x] T033 [US2] Create SelectionOverlayWindow NSPanel for full-screen overlay in ScreenCapture/Features/Capture/SelectionOverlayWindow.swift
- [x] T034 [US2] Implement crosshair cursor and dim overlay in SelectionOverlayWindow
- [x] T035 [US2] Track mouse drag and draw selection rectangle with real-time dimensions label
- [x] T036 [US2] Handle Escape key to cancel selection in SelectionOverlayWindow
- [x] T037 [US2] Support multi-display spanning (create overlay per NSScreen)
- [x] T038 [US2] Implement captureRegion(_:from:) in CaptureManager using SCContentFilter with crop
- [x] T039 [US2] Wire selection shortcut → SelectionOverlay → CaptureManager → PreviewWindow

**Checkpoint**: Partial selection capture works; dimensions shown during drag; Escape cancels

---

## Phase 6: User Story 4 - Save and Export (Priority: P2)

**Goal**: User can save (Enter/⌘S), copy (⌘C), or dismiss (Escape) from preview

**Independent Test**: Capture screenshot, press ⌘S, verify file saved to default location

### Implementation for User Story 4

- [x] T040 [US4] Create ImageExporter with CGImageDestination for PNG/JPEG in ScreenCapture/Services/ImageExporter.swift
- [x] T041 [US4] Implement save(_:annotations:to:format:quality:) with annotation compositing
- [x] T042 [US4] Add generateFilename(format:) with timestamp pattern in ImageExporter
- [x] T043 [US4] Create ClipboardService with NSPasteboard write in ScreenCapture/Services/ClipboardService.swift
- [x] T044 [US4] Add keyboard handlers in PreviewWindow: Enter/⌘S→save, ⌘C→copy, Escape→dismiss
- [x] T045 [US4] Add saved capture to RecentCapturesStore with thumbnail
- [x] T046 [US4] Show save error alerts with user-friendly messages and retry option

**Checkpoint**: Save, copy, dismiss all work; recent captures updated; errors shown gracefully

---

## Phase 7: User Story 3 - Annotation and Editing (Priority: P2)

**Goal**: User can draw rectangles, freehand lines, and text on screenshot with undo

**Independent Test**: Capture, press R, draw rectangle, press ⌘Z, verify rectangle removed

### Implementation for User Story 3

- [x] T047 [US3] Create Annotation enum with rectangle, freehand, text cases in ScreenCapture/Models/Annotation.swift
- [x] T048 [US3] Create AnnotationTool protocol in ScreenCapture/Features/Annotations/AnnotationTool.swift
- [x] T049 [P] [US3] Implement RectangleTool with drag gesture in ScreenCapture/Features/Annotations/RectangleTool.swift
- [x] T050 [P] [US3] Implement FreehandTool with continuous path in ScreenCapture/Features/Annotations/FreehandTool.swift
- [x] T051 [P] [US3] Implement TextTool with click-to-place and text field in ScreenCapture/Features/Annotations/TextTool.swift
- [x] T052 [US3] Create AnnotationCanvas SwiftUI Canvas view in ScreenCapture/Features/Preview/AnnotationCanvas.swift
- [x] T053 [US3] Add tool selection with keyboard shortcuts (R, D, T) in PreviewViewModel
- [x] T054 [US3] Add active tool indicator UI in PreviewContentView
- [x] T055 [US3] Implement undo/redo stack with UndoManager in PreviewViewModel
- [x] T056 [US3] Wire ⌘Z and ⌘⇧Z to undo/redo in PreviewWindow responder chain
- [x] T057 [US3] Create AnnotationRenderer for compositing annotations onto CGImage in ScreenCapture/Services/AnnotationRenderer.swift

**Checkpoint**: All three tools work; undo/redo functions; annotations saved with screenshot

---

## Phase 8: User Story 6 - Settings Configuration (Priority: P3)

**Goal**: User can configure save location, format, quality, and keyboard shortcuts

**Independent Test**: Open Settings, change save location, capture and save, verify new location used

### Implementation for User Story 6

- [x] T058 [US6] Create SettingsViewModel with AppSettings binding in ScreenCapture/Features/Settings/SettingsViewModel.swift
- [x] T059 [US6] Create SettingsView SwiftUI with all preference controls in ScreenCapture/Features/Settings/SettingsView.swift
- [x] T060 [US6] Add save location picker with folder selection panel
- [x] T061 [US6] Add format picker (PNG/JPEG) and JPEG quality slider
- [x] T062 [US6] Add keyboard shortcut recorder for capture hotkeys
- [x] T063 [US6] Add stroke color picker and width slider for annotations
- [x] T064 [US6] Add text size slider for text annotations
- [x] T065 [US6] Wire Settings menu item to open SettingsView in new window
- [x] T066 [US6] Persist settings to UserDefaults and reload on app launch

**Checkpoint**: All settings editable and persistent; changes take effect immediately

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, performance, edge cases, and final validation

- [x] T067 Add VoiceOver accessibility labels to all interactive elements
- [x] T068 Implement full keyboard navigation in preview and settings windows
- [x] T069 Respect Reduce Motion preference for animations
- [x] T070 Handle display disconnect during capture with user notification
- [x] T071 Handle disk full and permission errors with user-friendly alerts
- [x] T072 Profile memory usage and ensure ≤2× image size peak
- [x] T073 Profile capture latency and ensure <50ms
- [x] T074 Add screen recording permission prompt with explanation text
- [x] T075 Validate quickstart.md instructions work end-to-end
- [x] T076 Final code cleanup and remove any debug logging

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phase 3 (US5)**: Depends on Phase 2 - Menu bar must exist before captures
- **Phase 4 (US1)**: Depends on Phase 3 - Needs hotkeys from menu bar
- **Phase 5 (US2)**: Depends on Phase 4 - Reuses CaptureManager and PreviewWindow
- **Phase 6 (US4)**: Depends on Phase 4 - Needs preview window to save from
- **Phase 7 (US3)**: Depends on Phase 4 - Needs preview window for annotations
- **Phase 8 (US6)**: Depends on Phase 3 - Needs menu bar for Settings entry
- **Phase 9 (Polish)**: Depends on all user stories complete

### User Story Dependencies

```
         ┌──────────────────────────────────────┐
         │          Phase 2: Foundational       │
         └──────────────────────────────────────┘
                          │
                          ▼
         ┌──────────────────────────────────────┐
         │     Phase 3: US5 - Menu Bar (P1)     │
         └──────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │ Phase 4:    │ │ Phase 8:    │ │             │
   │ US1 - Full  │ │ US6 -       │ │             │
   │ Screen (P1) │ │ Settings    │ │             │
   └─────────────┘ │ (P3)        │ │             │
          │        └─────────────┘ │             │
          │                        │             │
   ┌──────┴──────────────┐        │             │
   ▼                     ▼        │             │
┌─────────────┐   ┌─────────────┐ │             │
│ Phase 5:    │   │ Phase 6:    │ │             │
│ US2 -       │   │ US4 - Save  │ │             │
│ Selection   │   │ (P2)        │ │             │
│ (P1)        │   └─────────────┘ │             │
└─────────────┘          │        │             │
                         ▼        │             │
                  ┌─────────────┐ │             │
                  │ Phase 7:    │ │             │
                  │ US3 -       │◀┘             │
                  │ Annotation  │               │
                  │ (P2)        │               │
                  └─────────────┘               │
                         │                      │
                         ▼                      │
         ┌──────────────────────────────────────┐
         │         Phase 9: Polish              │
         └──────────────────────────────────────┘
```

### Parallel Opportunities

**Phase 2 (Foundational)**: T007-T012, T014-T015 can all run in parallel

**Phase 7 (US3)**: T049-T051 (annotation tools) can run in parallel

**Phase 8 (US6)**: Can run in parallel with Phases 5-7 after Phase 3

### Within Each Phase

- Models/Errors before Services
- Services before ViewModels
- ViewModels before Views
- Core implementation before integration

---

## Parallel Execution Example: Phase 2

```bash
# Launch foundational models in parallel:
Task: "Create ScreenCaptureError enum in ScreenCapture/Errors/ScreenCaptureError.swift"
Task: "Create ExportFormat enum in ScreenCapture/Models/ExportFormat.swift"
Task: "Create DisplayInfo struct in ScreenCapture/Models/DisplayInfo.swift"
Task: "Create Screenshot struct in ScreenCapture/Models/Screenshot.swift"
Task: "Create StrokeStyle and TextStyle in ScreenCapture/Models/Styles.swift"
Task: "Create KeyboardShortcut struct in ScreenCapture/Models/KeyboardShortcut.swift"
Task: "Create NSImage+Extensions in ScreenCapture/Extensions/NSImage+Extensions.swift"
Task: "Create CGImage+Extensions in ScreenCapture/Extensions/CGImage+Extensions.swift"

# Then sequentially:
Task: "Create AppSettings with UserDefaults persistence"  # depends on KeyboardShortcut
Task: "Create ScreenCaptureApp.swift"
Task: "Create AppDelegate.swift"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 5)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: US5 - Menu Bar Interface
4. Complete Phase 4: US1 - Full Screen Capture
5. **STOP and VALIDATE**: App captures full screen and shows preview
6. Deploy/demo MVP

### Incremental Delivery

1. MVP: Setup + Foundational + US5 + US1 → Full screen capture works
2. Add US2 → Partial selection capture works
3. Add US4 → Save and export works
4. Add US3 → Annotations work
5. Add US6 → Settings configurable
6. Polish → Accessibility, performance, edge cases

### Single Developer Strategy

Execute phases sequentially in priority order:
1. Phase 1-2: Setup + Foundation (required)
2. Phase 3-4: US5 + US1 (MVP)
3. Phase 5: US2 (completes capture feature)
4. Phase 6: US4 (completes save workflow)
5. Phase 7: US3 (adds annotation value)
6. Phase 8: US6 (adds customization)
7. Phase 9: Polish

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently testable after its phase completes
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All ViewModels must be @MainActor; CaptureManager is an actor
- Use async/await for all ScreenCaptureKit and file I/O operations
