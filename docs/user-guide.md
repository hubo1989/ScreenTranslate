# User Guide

Welcome to ScreenCapture! This guide will help you get the most out of your screen capture experience.

## Getting Started

### System Requirements

- macOS 13.0 (Ventura) or later
- Screen Recording permission

### Installation

1. Download ScreenCapture
2. Drag to Applications folder
3. Launch the app

### First Launch

On first launch, you'll be prompted to grant **Screen Recording** permission:

1. Click "Open System Settings" in the permission dialog
2. Navigate to **Privacy & Security → Screen Recording**
3. Toggle on ScreenCapture
4. Restart the app if prompted

The app runs in your menu bar with a camera icon.

---

## Capturing Screenshots

### Full Screen Capture

**Method 1: Keyboard Shortcut**
- Press `Cmd + Shift + 3`

**Method 2: Menu Bar**
- Click the camera icon in menu bar
- Select "Capture Full Screen"

If you have multiple monitors, a menu will appear to select which display to capture.

### Selection Capture

**Method 1: Keyboard Shortcut**
- Press `Cmd + Shift + 4`

**Method 2: Menu Bar**
- Click the camera icon in menu bar
- Select "Capture Selection"

**Drawing the Selection:**
1. Click and drag to draw a rectangle
2. The selected area is highlighted
3. Release to capture
4. Press `Escape` to cancel

---

## Preview Window

After capturing, the Preview window appears showing your screenshot.

### Window Controls

| Action | Result |
|--------|--------|
| Drag edges | Resize window |
| Drag title bar | Move window |
| Close button | Dismiss without saving |

### Quick Actions

| Shortcut | Action |
|----------|--------|
| `Enter` or `Cmd+S` | Save screenshot |
| `Cmd+C` | Copy to clipboard and close |
| `Escape` | Dismiss window |

---

## Annotation Tools

Add annotations to highlight or explain parts of your screenshot.

### Selecting Tools

**Keyboard:**

| Key | Tool |
|-----|------|
| `R` or `1` | Rectangle |
| `D` or `2` | Freehand Drawing |
| `A` or `3` | Arrow |
| `T` or `4` | Text |

**Mouse:**
- Click tool buttons in the toolbar

### Using Each Tool

#### Rectangle Tool (R/1)

Draw rectangular shapes to highlight areas.

1. Select the Rectangle tool
2. Click and drag to draw
3. Release to complete

**Options:**
- Color: Change in toolbar
- Stroke width: Adjust slider
- Filled: Toggle for solid fill

#### Freehand Tool (D/2)

Draw freeform lines and shapes.

1. Select the Freehand tool
2. Click and drag to draw
3. Release to complete

**Tips:**
- Draw smoothly for best results
- Points are optimized automatically

#### Arrow Tool (A/3)

Draw arrows to point at important elements.

1. Select the Arrow tool
2. Click at arrow start point
3. Drag to arrow end point
4. Release to complete

**Tips:**
- Arrow head appears at end point
- Minimum 5pt length required

#### Text Tool (T/4)

Add text labels to your screenshot.

1. Select the Text tool
2. Click where you want text
3. Type your text
4. Click elsewhere or press Enter to confirm

**Options:**
- Font size: Adjust in toolbar
- Color: Change in toolbar

### Editing Annotations

**Select an annotation:**
- Click on any annotation to select it
- Selected annotations show handles

**Move an annotation:**
- Drag a selected annotation to reposition

**Change color:**
- Select annotation, then pick new color

**Delete an annotation:**
- Select annotation
- Press `Delete` or `Backspace`

### Undo/Redo

| Shortcut | Action |
|----------|--------|
| `Cmd+Z` | Undo last action |
| `Shift+Cmd+Z` | Redo |

Up to 50 actions can be undone.

---

## Cropping

Crop your screenshot to focus on a specific area.

### Enter Crop Mode

- Press `C` or click the Crop button

### Cropping Steps

1. Enter crop mode (overlay appears)
2. Drag to draw crop rectangle
3. Adjust by dragging edges/corners
4. Press `Enter` to apply crop
5. Press `Escape` to cancel

**Note:** Cropping removes all annotations. Save first if you want to keep them.

---

## Saving Screenshots

### Save to Disk

1. Press `Enter` or `Cmd+S`
2. Screenshot saves to your configured location
3. Window closes automatically

**Default location:** Desktop
**Default format:** PNG

### Copy to Clipboard

1. Press `Cmd+C`
2. Screenshot (with annotations) copies to clipboard
3. Window closes automatically
4. Paste in any app with `Cmd+V`

---

## Settings

Access settings via menu bar → Settings (or `Cmd+,`).

### Save Location

Choose where screenshots are saved by default.

1. Click "Choose..."
2. Select folder
3. Click "Select"

### Default Format

Choose between:
- **PNG** - Lossless, larger files (~1.5 bytes/pixel)
- **JPEG** - Lossy, smaller files (~0.3 bytes/pixel)

### JPEG Quality

When using JPEG format, adjust quality:
- **Higher:** Better quality, larger files
- **Lower:** Smaller files, some artifacts

Range: 0% to 100% (default: 90%)

### Keyboard Shortcuts

Customize global hotkeys:

1. Click the shortcut field
2. Press your new key combination
3. Must include Cmd, Ctrl, or Option

**Defaults:**
- Full Screen: `Cmd+Shift+3`
- Selection: `Cmd+Shift+4`

### Annotation Defaults

Set default styles for new annotations:

- **Stroke Color:** Default annotation color
- **Stroke Width:** Line thickness (1-20pt)
- **Text Size:** Font size for text tool (8-72pt)
- **Rectangle Filled:** Toggle outline vs. solid

### Reset to Defaults

Click "Reset to Defaults" to restore all settings.

---

## Recent Captures

Access recently saved screenshots from the menu bar.

1. Click menu bar icon
2. Hover over "Recent Captures"
3. Click any capture to open in Finder

**Features:**
- Shows last 5 captures
- Displays thumbnails
- "Clear Recent" removes the list

---

## Keyboard Shortcuts Reference

### Global (work anytime)

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+3` | Capture full screen |
| `Cmd+Shift+4` | Capture selection |

### In Preview Window

| Shortcut | Action |
|----------|--------|
| `Enter` / `Cmd+S` | Save screenshot |
| `Cmd+C` | Copy and close |
| `Escape` | Deselect / Dismiss |
| `Delete` | Delete selected annotation |
| `Cmd+Z` | Undo |
| `Shift+Cmd+Z` | Redo |
| `R` / `1` | Rectangle tool |
| `D` / `2` | Freehand tool |
| `A` / `3` | Arrow tool |
| `T` / `4` | Text tool |
| `C` | Toggle crop mode |

### In Selection Mode

| Shortcut | Action |
|----------|--------|
| `Escape` | Cancel selection |
| Click + Drag | Draw selection |
| Release | Complete capture |

---

## Tips & Tricks

### Quick Annotation Workflow

1. Capture with `Cmd+Shift+4`
2. Draw selection
3. Press `R` for rectangle
4. Draw highlight
5. Press `Cmd+C` to copy

Total time: ~3 seconds!

### Multi-Monitor Capture

When capturing full screen with multiple monitors:
- A menu appears to select the display
- Primary display is marked
- Each display shows resolution

### Retina Display

Screenshots automatically capture at native resolution:
- 2x on Retina displays
- 1x on standard displays

File sizes will be larger for Retina captures.

### Keyboard-Only Workflow

Never touch the mouse:
1. `Cmd+Shift+3` - Capture
2. `R` - Rectangle tool
3. Use mouse to draw (unavoidable)
4. `Cmd+S` - Save

---

## Troubleshooting

### "Permission Denied" Error

**Solution:**
1. Open System Settings
2. Go to Privacy & Security → Screen Recording
3. Ensure ScreenCapture is enabled
4. Restart the app

### Hotkeys Not Working

**Possible causes:**
- Another app uses the same shortcut
- Modifiers missing (need Cmd, Ctrl, or Option)

**Solution:**
1. Open Settings
2. Change to different shortcut
3. Restart app

### Black/Blank Screenshots

**Possible causes:**
- Display disconnected during capture
- Permission revoked

**Solution:**
1. Verify display connection
2. Re-grant Screen Recording permission
3. Restart app

### App Not in Menu Bar

**Solution:**
1. Check if app is running (Activity Monitor)
2. Quit and relaunch
3. Check menu bar overflow (>>)

### Cannot Save Screenshot

**Possible causes:**
- Save location not writable
- Disk full

**Solution:**
1. Open Settings
2. Choose different save location
3. Free up disk space

---

## Privacy & Security

### Screen Recording Permission

ScreenCapture requires Screen Recording permission to function. This permission:
- Allows the app to capture screen contents
- Is managed by macOS system settings
- Can be revoked at any time

### Data Storage

- Screenshots are saved locally
- No data is sent to external servers
- Recent captures list stored in preferences

### Revoking Access

To revoke Screen Recording permission:
1. Open System Settings
2. Go to Privacy & Security → Screen Recording
3. Toggle off ScreenCapture

---

## Support

If you encounter issues not covered in this guide:

1. Check the Troubleshooting section above
2. Restart the application
3. Review system permissions
4. Contact support with:
   - macOS version
   - Steps to reproduce
   - Error messages (if any)
