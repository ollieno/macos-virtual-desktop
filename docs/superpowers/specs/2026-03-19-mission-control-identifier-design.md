# Mission Control Desktop Identifier

## Problem

When Mission Control is open, there is no clear visual indicator showing which desktop you are currently on. The existing colored border is too subtle in the Mission Control thumbnail view.

## Solution

A persistent label window per desktop that sits behind all other windows. In normal use it is hidden behind app windows. When Mission Control is activated, macOS shows all windows as separate thumbnails, making the label visible as a recognizable "app window" displaying the desktop name.

## Design Decisions

### Window Properties

| Property | Value | Rationale |
|----------|-------|-----------|
| Size | 700 x 200 pt | Large enough to remain readable in Mission Control thumbnails (~15-20% scale) |
| Position | Centered on screen | Maximum visibility in Mission Control |
| Window level | Below normal (`.normal - 1` or `.desktopIcon + 1`) | Always behind app windows in normal use |
| Mouse events | `ignoresMouseEvents = true` | Click-through so it never interferes with normal use |
| Collection behavior | Default (no `canJoinAllSpaces`) | Each desktop gets its own window instance |

### Visual Style

- **Background**: dark (rgba 15, 15, 20, 0.85) with rounded corners (14pt radius)
- **Text**: white, bold (800 weight), large font (~48pt), showing desktop number + name (e.g. "1: Code")
- **Border**: 3pt stroke in the desktop's color from `DesktopColors.palette`
- **Shadow**: subtle drop shadow for depth

### Behavior

- One `IdentifierWindow` per screen, per desktop
- Window content updates when desktop name changes (via `NameStore`)
- Window color updates based on desktop index (via `DesktopColors`)
- Toggle: `Settings.showIdentifier` (UserDefaults key "showIdentifier"), default `true`
- Menu item in the app menu to toggle on/off, alongside existing "Show Border" toggle

### Edge Cases

- **Empty desktop**: label is visible directly on the wallpaper. This is acceptable and even helpful.
- **Multiple screens**: one identifier window per screen, same as `BorderController` pattern.
- **Desktop added/removed**: windows are recreated when space configuration changes, following existing `BorderController` lifecycle.
- **Name change**: window text updates immediately via the existing notification pattern.

## Architecture

### New Files

- `VirtualDesktop/UI/IdentifierWindow.swift`: contains `IdentifierPanel` (NSPanel subclass) and `IdentifierController` (manages panel lifecycle per screen/desktop)

### Modified Files

- `VirtualDesktop/Services/Settings.swift`: add `showIdentifier` property
- `VirtualDesktop/UI/MenuBarController.swift`: add toggle menu item, create/manage `IdentifierController`, update identifier on desktop switch

### Pattern

Follows the same architecture as `BorderWindow.swift`:
- `IdentifierPanel` extends `NSPanel` (borderless, non-activating)
- `IdentifierController` manages one panel per screen
- SwiftUI `IdentifierView` for the label content
- Controller is owned by `MenuBarController` and updated on space change

### Key Differences from BorderController

| Aspect | BorderController | IdentifierController |
|--------|-----------------|---------------------|
| Collection behavior | `canJoinAllSpaces` | Default (per-desktop) |
| Window level | `.statusBar` | Below `.normal` |
| Content | 4pt border stroke | Centered label with background |
| Size | Full screen | 700 x 200 pt centered |
| Mouse events | Ignored | Ignored |

## Toggle Integration

- `Settings.showIdentifier`: Bool, defaults to `true`
- Menu item: "Show Desktop Identifier" with checkmark, below existing "Show Border"
- When toggled off: all identifier panels are hidden
- When toggled on: panels are created/shown for current desktop
