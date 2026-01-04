# Feature Specification: ScreenCapture - macOS Screenshot Application

**Feature Branch**: `001-screen-capture`
**Created**: 2026-01-04
**Status**: Draft
**Input**: User description: "Build a lightweight, native macOS screenshot application"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Full Screen Capture (Priority: P1)

As a user, I want to capture my entire screen instantly with a keyboard shortcut so
that I can quickly grab what I'm looking at without interrupting my workflow.

**Why this priority**: This is the most common screenshot use case. Users need a fast,
reliable way to capture their full screen. This forms the foundation of the application.

**Independent Test**: Can be fully tested by pressing the global shortcut and verifying
a screenshot is captured and preview appears.

**Acceptance Scenarios**:

1. **Given** the app is running in the menu bar, **When** I press the full screen capture
   shortcut, **Then** the entire screen is captured and a preview window appears within
   50ms.
2. **Given** I have multiple monitors connected, **When** I trigger full screen capture,
   **Then** I can select which display to capture before the capture occurs.
3. **Given** a full screen capture is taken, **When** the preview appears, **Then** it
   shows image dimensions and estimated file size.

---

### User Story 2 - Partial Screen Selection (Priority: P1)

As a user, I want to select a specific region of my screen to capture so that I can
share only the relevant portion without cropping afterward.

**Why this priority**: Region selection is equally essential as full screen capture.
Users frequently need to capture specific windows, UI elements, or portions of content.

**Independent Test**: Can be tested by triggering selection mode, dragging to select
a region, and verifying only that region is captured.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** I press the selection capture shortcut,
   **Then** a crosshair cursor appears over the screen.
2. **Given** I am in selection mode, **When** I click and drag, **Then** a selection
   rectangle appears with real-time pixel dimensions displayed.
3. **Given** I have selected a region, **When** I release the mouse button, **Then**
   only the selected region is captured and preview appears.
4. **Given** I am in selection mode, **When** I press Escape, **Then** selection is
   cancelled and no capture occurs.
5. **Given** I have multiple monitors, **When** I enter selection mode, **Then** I can
   select regions spanning multiple displays.

---

### User Story 3 - Annotation and Editing (Priority: P2)

As a user, I want to annotate my screenshots with rectangles, freehand drawings, and
text so that I can highlight important areas or add context before sharing.

**Why this priority**: Annotations add significant value by eliminating the need for
external editing tools. This differentiates the app from basic screenshot utilities.

**Independent Test**: Can be tested by capturing a screenshot, using each annotation
tool, and verifying annotations appear correctly on the image.

**Acceptance Scenarios**:

1. **Given** the preview window is open, **When** I press 'R', **Then** the rectangle
   tool is activated and a visual indicator shows it's active.
2. **Given** rectangle tool is active, **When** I click and drag on the image, **Then**
   a rectangle with the configured stroke color and width is drawn.
3. **Given** the preview window is open, **When** I press 'D', **Then** the freehand
   drawing tool is activated.
4. **Given** freehand tool is active, **When** I draw with my mouse, **Then** a line
   follows my cursor with the configured stroke color and width.
5. **Given** the preview window is open, **When** I press 'T', **Then** the text tool
   is activated.
6. **Given** text tool is active, **When** I click on the image, **Then** a text
   insertion cursor appears at that location.
7. **Given** text insertion is active, **When** I type, **Then** text appears using
   SF Pro (system font) with configured color and size.
8. **Given** I have made annotations, **When** I press Cmd+Z, **Then** the last
   annotation is undone.
9. **Given** I have undone annotations, **When** I press Cmd+Shift+Z, **Then** the
   undone annotation is restored.

---

### User Story 4 - Save and Export (Priority: P2)

As a user, I want to save my screenshots with annotations in my preferred format and
location so that I can organize and share them easily.

**Why this priority**: Saving and export are essential to complete the capture workflow.
Without this, captures would be lost when the preview is dismissed.

**Independent Test**: Can be tested by capturing a screenshot, adding annotations,
and saving via keyboard shortcuts.

**Acceptance Scenarios**:

1. **Given** the preview window is open, **When** I press Enter or Cmd+S, **Then** the
   screenshot (with annotations) is saved to the configured default location.
2. **Given** the preview window is open, **When** I press Cmd+C, **Then** the screenshot
   (with annotations) is copied to the clipboard.
3. **Given** the preview window is open, **When** I press Escape, **Then** the preview
   is dismissed without saving.
4. **Given** I have set PNG as my default format, **When** I save, **Then** the file is
   saved as PNG with lossless compression.
5. **Given** I have set JPEG as my default format, **When** I save, **Then** the file is
   saved as JPEG with my configured compression level.
6. **Given** I save a screenshot, **Then** it appears in the Recent Captures list in
   the menu.

---

### User Story 5 - Menu Bar Interface (Priority: P1)

As a user, I want to access screenshot functions from a clean menu bar icon so that
the app stays out of my way while remaining easily accessible.

**Why this priority**: The menu bar is the primary interface. It must be minimal yet
provide quick access to all functions. Essential for app usability.

**Independent Test**: Can be tested by clicking the menu bar icon and verifying all
menu items are present and functional.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** I look at the menu bar, **Then** I see a
   screenshot icon (no dock icon visible).
2. **Given** I click the menu bar icon, **When** the menu opens, **Then** I see:
   Capture Full Screen (with shortcut), Capture Selection (with shortcut), Recent
   Captures, Settings, Quit.
3. **Given** I expand Recent Captures, **When** there are recent screenshots, **Then**
   I see up to the last 5 captures with thumbnails or filenames.
4. **Given** I click Settings, **Then** a preferences window opens.

---

### User Story 6 - Settings Configuration (Priority: P3)

As a user, I want to configure my preferences for save location, format, quality, and
keyboard shortcuts so that the app works the way I prefer.

**Why this priority**: While important for personalization, the app should work with
sensible defaults. Settings enhance the experience but aren't required for basic use.

**Independent Test**: Can be tested by opening settings, changing each preference, and
verifying the changes take effect.

**Acceptance Scenarios**:

1. **Given** the settings window is open, **When** I look at available options, **Then**
   I see: default save location, default format (PNG/JPEG), JPEG quality slider,
   keyboard shortcuts configuration.
2. **Given** I change the default save location, **When** I save a new screenshot,
   **Then** it is saved to the new location.
3. **Given** I set JPEG quality to 80%, **When** I save as JPEG, **Then** the file uses
   80% compression.
4. **Given** I change the full screen capture shortcut, **When** I press the new
   shortcut, **Then** full screen capture is triggered.
5. **Given** I change settings, **Then** my preferences persist across app restarts.

---

### Edge Cases

- What happens when a display is disconnected during capture? App should gracefully
  handle the change and notify the user if the target display is no longer available.
- What happens when save location is inaccessible (permissions, full disk)? App should
  show a user-friendly error with option to choose alternate location.
- What happens when clipboard write fails? App should show error and suggest retry.
- What happens if user tries to use a shortcut already used by the system or another
  app? Settings should warn about conflicts and require confirmation.
- What happens with very large captures (8K displays, multi-monitor spans)? App should
  handle gracefully, potentially showing a progress indicator and managing memory.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST capture the entire screen when the full screen capture
  shortcut is pressed.
- **FR-002**: System MUST display a crosshair cursor and selection overlay when partial
  screen capture is initiated.
- **FR-003**: System MUST show real-time pixel dimensions during region selection.
- **FR-004**: System MUST detect all connected displays and allow selection of capture
  target.
- **FR-005**: System MUST display a preview window immediately after capture completes.
- **FR-006**: Preview window MUST remain always-on-top until dismissed.
- **FR-007**: Preview window MUST show image dimensions and estimated file size.
- **FR-008**: System MUST provide rectangle drawing tool activated by 'R' key.
- **FR-009**: System MUST provide freehand drawing tool activated by 'D' key.
- **FR-010**: System MUST provide text annotation tool activated by 'T' key.
- **FR-011**: System MUST display a visual indicator showing the currently active tool.
- **FR-012**: System MUST support undo (Cmd+Z) for all annotation operations.
- **FR-013**: System MUST copy screenshot with annotations to clipboard on Cmd+C.
- **FR-014**: System MUST save screenshot with annotations on Enter or Cmd+S.
- **FR-015**: System MUST dismiss preview without saving on Escape.
- **FR-016**: System MUST support PNG and JPEG export formats.
- **FR-017**: System MUST provide configurable JPEG compression (1-100, default 90%).
- **FR-018**: System MUST remember user's format preference.
- **FR-019**: System MUST run as menu bar application (no dock icon by default).
- **FR-020**: Menu MUST include: Capture Full Screen, Capture Selection, Recent
  Captures (last 5), Settings, Quit.
- **FR-021**: Settings MUST include: save location, default format, JPEG quality,
  keyboard shortcuts configuration.
- **FR-022**: System MUST request screen recording permission with clear explanation.
- **FR-023**: Annotation stroke color and width MUST be configurable.
- **FR-024**: Text annotation MUST use SF Pro (system font) with configurable size.

### Key Entities

- **Screenshot**: A captured image with metadata (dimensions, capture date, source
  display, format, file path).
- **Annotation**: A drawing element (rectangle, freehand path, or text) with styling
  properties (color, stroke width, font size) and position.
- **Display**: A connected monitor with identifier, resolution, scale factor, and
  arrangement position.
- **Preferences**: User configuration including save location, default format, JPEG
  quality, keyboard shortcuts, annotation defaults.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can capture full screen within 50ms of pressing the shortcut.
- **SC-002**: Preview window appears within 100ms of capture completion.
- **SC-003**: Application is ready to capture within 1 second of launch.
- **SC-004**: Application uses less than 1% CPU when idle in the menu bar.
- **SC-005**: Memory usage for a single capture does not exceed 2x the raw image size.
- **SC-006**: Primary capture-to-save workflow completes in 3 keystrokes or fewer.
- **SC-007**: All annotation tools respond visually within 16ms of user input (60fps).
- **SC-008**: Application supports users with VoiceOver and keyboard-only navigation.
- **SC-009**: Users with multi-monitor setups can capture any connected display.
- **SC-010**: Saved screenshots maintain visual fidelity (PNG lossless; JPEG at
  configured quality).
- **SC-011**: User preferences persist correctly across application restarts.
- **SC-012**: 90% of users can complete their first capture without reading documentation.

## Assumptions

- Target platform is macOS Tahoe 26.2+ on Apple Silicon (arm64).
- Users have granted or will grant screen recording permission when prompted.
- Default save location is ~/Desktop if not configured.
- Default keyboard shortcuts: Cmd+Shift+3 for full screen, Cmd+Shift+4 for selection
  (configurable to avoid system conflicts).
- Default annotation stroke color is red (#FF0000) with 2pt stroke width.
- Default text size is 14pt.
- Redo is supported via Cmd+Shift+Z (standard macOS convention).
- Recent captures list shows filename and thumbnail; clicking opens in Finder.
- JPEG default quality is 90%.
- PNG is used when transparency is present in the capture (window shadows, etc.).
