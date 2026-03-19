# Move Window to Desktop

A global hotkey that lets users move the active window to another named desktop via a quick-pick menu.

## Problem

macOS has no native keyboard shortcut to move a window to another Space. The only options are dragging to the screen edge (slow, unreliable) or dragging in Mission Control (requires mouse). This is the #4 most cited frustration among macOS virtual desktop users.

## Solution

A single configurable global hotkey (default: `Ctrl+Shift+M`) pops up an NSMenu centered on the active window, listing all other desktops by name. Selecting a desktop moves the active window there. The user stays on the current desktop.

## New Components

### `HotkeyManager.swift` (Service)

Manages global hotkey registration using a CGEvent tap.

Responsibilities:
- Creates a CGEvent tap listening for keyDown events
- Compares key code and modifiers against the configured hotkey
- Consumes matching events and fires a callback
- Supports re-registration when the user changes the hotkey

Default hotkey: `Ctrl+Shift+M`.

### `WindowMover.swift` (Service)

Handles the actual window movement using Accessibility API and SkyLight private APIs.

Responsibilities:
- Gets the frontmost application via `NSWorkspace.shared.frontmostApplication`
- Gets the focused window via `AXUIElement` (`kAXFocusedWindowAttribute`)
- Reads window position and size via `kAXPositionAttribute` and `kAXSizeAttribute`
- Extracts the CGWindowID from the AXUIElement
- Calls `PrivateAPIs.moveWindows([windowID], toSpace: targetSpaceID)` to move the window

### `MoveToDesktopMenu.swift` (UI)

Builds and displays the desktop picker menu.

Responsibilities:
- Gets all desktops from `SpaceDetector.allSpaces()`
- Gets names from `NameStore`
- Filters out the current desktop (no point moving to where you already are)
- Formats items as `"1: Name"` with desktop color indicators
- Calculates center point of the active window (from WindowMover)
- Shows menu at that position via `NSMenu.popUp(positioning:at:in:)`
- On selection, calls `WindowMover.moveActiveWindow(toSpaceID:)`

## Changes to Existing Components

### `PrivateAPIs.swift`

New function pointers loaded via dlsym:
- `SLSMoveWindowsToManagedSpace(connectionID, windowIDArray, targetSpaceID)`: Moves windows to a managed Space. Same API used by yabai.

New public method:
- `moveWindows(_ windowIDs: [UInt32], toSpace spaceID: UInt64)`: Wraps the SkyLight call.

### `Settings.swift`

New properties:
- `moveWindowKeyCode: UInt16`: The key code for the hotkey (default: `0x2E`, the M key)
- `moveWindowModifiers: UInt64`: The modifier flags (default: Ctrl + Shift)

### `MenuBarController.swift`

- Receives `HotkeyManager` and `MoveToDesktopMenu` as dependencies
- Hotkey callback triggers `MoveToDesktopMenu.show()`
- New menu item "Move Window Shortcut: Ctrl+Shift+M" in the settings section
- Clicking the menu item opens a key capture panel

### `AppDelegate.swift`

- Initializes `HotkeyManager` and `WindowMover` at launch
- Passes them to `MenuBarController`

## Data Flow

```
User presses Ctrl+Shift+M
    |
    v
HotkeyManager (CGEvent tap catches keyDown)
    | callback
    v
MenuBarController
    | calls
    v
MoveToDesktopMenu.show()
    +-- SpaceDetector.allSpaces() -> desktop list
    +-- SpaceDetector.activeSpaceUUID() -> current desktop (filtered out)
    +-- NameStore -> names for each desktop
    +-- WindowMover -> active window center point
    +-- NSMenu.popUp(positioning:at:in:) -> shows at window center
            |
            user selects desktop
            |
            v
    MoveToDesktopMenu callback -> WindowMover.moveActiveWindow(toSpaceID:)
            +-- NSWorkspace.frontmostApplication -> active app
            +-- AXUIElement -> focused window -> window ID
            +-- PrivateAPIs.moveWindows([windowID], toSpace: targetSpaceID)
```

## Hotkey Configuration

- Menu bar menu shows "Move Window Shortcut: Ctrl+Shift+M" (displaying current hotkey)
- Clicking opens a small NSPanel with "Press a key combination..."
- User presses desired combination, panel displays it and saves to Settings
- HotkeyManager re-registers with the new combination
- Validation: at least one modifier key required (Ctrl, Cmd, Option, or Shift)
- If the combination conflicts with a system shortcut, the CGEvent tap silently fails to capture it; a warning is shown

## Edge Cases

- **No active window**: If no window is focused (e.g. desktop background), the menu is not shown. Silent no-op.
- **Non-movable window**: System windows (Finder desktop, menu bar) are not movable. We check `kAXMovableAttribute` and skip if false.
- **Single desktop**: If only 1 desktop exists, the menu is not shown (nowhere to move to).
- **Fullscreen windows**: Fullscreen apps live in their own Space. We attempt the move, but if SkyLight refuses, it is a silent no-op.

## Permissions

No new permissions required. The app already needs Accessibility permission for SkyLight API access.

## Testing

- `HotkeyManagerTests`: Verify hotkey matching logic (key code + modifier comparison)
- `WindowMoverTests`: Test edge case handling (no window, non-movable window)
- `MoveToDesktopMenuTests`: Test menu construction (filtering current desktop, correct formatting)
- Integration testing: manual verification of the full flow on macOS
