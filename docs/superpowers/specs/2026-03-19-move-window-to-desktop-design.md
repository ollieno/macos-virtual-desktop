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
- Creates a CGEvent tap (type `.cgSessionEventTap`) listening for keyDown events
- Compares key code and modifiers against the configured hotkey
- Consumes matching events and fires a callback
- Supports re-registration when the user changes the hotkey
- The CGEvent tap callback dispatches to `DispatchQueue.main` before triggering any UI work
- If the tap cannot be created (permission denied), logs a warning and sets an `isActive` flag to false so the UI can inform the user

Requires: Accessibility permission (for CGEvent tap creation).

Default hotkey: `Ctrl+Shift+M`.

### `WindowMover.swift` (Service)

Handles the actual window movement using Accessibility API and SkyLight private APIs.

Responsibilities:
- Gets the frontmost application via `NSWorkspace.shared.frontmostApplication`
- Gets the focused window via `AXUIElement` (`kAXFocusedWindowAttribute`)
- Reads window position and size via `kAXPositionAttribute` and `kAXSizeAttribute` (used for menu positioning)
- Extracts the CGWindowID using `_AXUIElementGetWindow()` loaded via dlsym from the ApplicationServices framework
- Calls `PrivateAPIs.moveWindows([windowID], toSpace: targetSpaceID)` to move the window
- After moving, saves the current space ID and verifies macOS did not auto-switch. If it did, switches back using `SLSGetActiveSpace` to detect the switch, then relies on a brief delay to confirm no auto-follow occurred. The System Preferences setting "When switching to an application, switch to a Space with open windows" can affect this behavior.

### `MoveToDesktopMenu.swift` (UI)

Builds and displays the desktop picker menu.

Responsibilities:
- Gets all desktops from `SpaceDetector.allSpaces()`
- Gets names from `NameStore`
- Filters out the current desktop (no point moving to where you already are)
- Shows only desktops from the same display as the active window. Moving windows across displays is not supported in this version.
- Formats items as `"1: Name"` with desktop color indicators
- Calculates center point of the active window (from WindowMover's position/size attributes)
- Creates a transparent, borderless NSWindow at the target screen position, then uses `NSMenu.popUp(positioning:at:in:)` relative to that window's contentView for reliable positioning
- On selection, calls `WindowMover.moveActiveWindow(toSpaceID:)`

## Changes to Existing Components

### `PrivateAPIs.swift`

New function pointer loaded via dlsym:
- `SLSMoveWindowsToManagedSpace(conn: CGSConnectionID, windowIDs: CFArray, spaceID: CGSSpaceID)`: Moves windows to a managed Space. Same API used by yabai.

New static method (PrivateAPIs is an enum used as namespace):
- `static func moveWindows(_ windowIDs: [UInt32], toSpace spaceID: UInt64)`: Wraps the SkyLight call. Returns `false` if `SLSMoveWindowsToManagedSpace` was not loaded via dlsym (may not exist on all macOS versions).

### `Settings.swift`

New properties:
- `moveWindowKeyCode: UInt16`: The key code for the hotkey (default: `0x2E`, the M key)
- `moveWindowModifiers: UInt64`: The modifier flags (default: Ctrl + Shift)

### `MenuBarController.swift`

- Init signature extended to `init(spaceDetector:, nameStore:, hotkeyManager:, windowMover:)`
- `MoveToDesktopMenu` is created internally (it needs SpaceDetector, NameStore, and WindowMover)
- Hotkey callback triggers `MoveToDesktopMenu.show()`
- New menu item "Move Window Shortcut: Ctrl+Shift+M" in the settings section
- Clicking the menu item opens a key capture panel

### `AppDelegate.swift`

- Initializes `HotkeyManager` and `WindowMover` at launch
- Checks `AXIsProcessTrusted()` and prompts for Accessibility permission if not granted (in addition to the existing Screen Recording permission check)
- Passes HotkeyManager and WindowMover to `MenuBarController`

## Data Flow

```
User presses Ctrl+Shift+M
    |
    v
HotkeyManager (CGEvent tap catches keyDown on run loop thread)
    | dispatches to DispatchQueue.main
    v
MenuBarController (main thread)
    | calls
    v
MoveToDesktopMenu.show()
    +-- SpaceDetector.allSpaces() -> desktop list
    +-- SpaceDetector.activeSpaceUUID() -> current desktop (filtered out)
    +-- NameStore -> names for each desktop
    +-- WindowMover -> active window center point
    +-- Creates transparent positioning window
    +-- NSMenu.popUp(positioning:at:in:) -> shows at window center
            |
            user selects desktop
            |
            v
    MoveToDesktopMenu callback -> WindowMover.moveActiveWindow(toSpaceID:)
            +-- NSWorkspace.frontmostApplication -> active app
            +-- AXUIElement -> focused window
            +-- _AXUIElementGetWindow() -> CGWindowID
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
- **Multi-display**: The menu shows only desktops from the display where the active window resides. Cross-display window movement is out of scope for this version.
- **Auto-follow prevention**: macOS may auto-switch to the target Space after moving the window (depending on System Preferences). WindowMover detects this and stays on the current Space.

## Permissions

Requires **Accessibility permission** (new). Needed for:
- `AXUIElement` calls to get the focused window and its attributes
- `CGEvent` tap creation

The existing Screen Recording permission (for SkyLight space detection) is unchanged.

`AppDelegate` checks `AXIsProcessTrusted()` at launch and prompts the user if not granted.

## Error Handling

- **`SLSMoveWindowsToManagedSpace` not available via dlsym**: `PrivateAPIs.moveWindows()` returns `false`. The feature is silently disabled. This could happen on future macOS versions.
- **CGEvent tap creation fails**: `HotkeyManager.isActive` is set to `false`. The menu item shows "Move Window Shortcut: unavailable" instead of the key combination.
- **`_AXUIElementGetWindow` not available**: Falls back to matching via `CGWindowListCopyWindowInfo` by PID and window title.
- All failures are logged via `os_log` for debugging purposes. No user-facing error dialogs for transient failures.

## Testing

- `HotkeyManagerTests`: Verify hotkey matching logic (key code + modifier comparison)
- `WindowMoverTests`: Test edge case handling (no window, non-movable window, window center calculation)
- `MoveToDesktopMenuTests`: Test menu construction (filtering current desktop, filtering other displays, correct formatting)
- Integration testing: manual verification of the full flow on macOS
