# VirtualDesktop: macOS Space Namer

## Problem

macOS Spaces (virtual desktops) only show generic names like "Desktop 1", "Desktop 2" in Mission Control. When working with 10+ desktops and frequently switching between them, there is no way to quickly identify which desktop serves which purpose.

## Solution

A native macOS menu bar app that lets users assign custom names to their Spaces and always shows the current desktop's name.

## MVP Scope

### Features

1. **Menu bar item** showing the current desktop's custom name (e.g. "Code", "Email", "Design"). Truncated to max 20 characters with ellipsis to prevent menu bar overflow.
2. **Dropdown menu** listing all desktops with their names
3. **Rename via popover**: clicking "Rename..." next to a desktop opens an NSPopover with an NSTextField for editing. This avoids the known first-responder issues with custom views inside NSMenu.
4. **Auto-detect desktop switches** and update the displayed name
5. **Persist names** across app restarts
6. **Launch at login** via SMAppService (macOS 13+)

### Out of Scope (future)

- Overlay notification on desktop switch (like macOS volume indicator)
- Keyboard shortcuts to jump to a desktop by name
- Automatic naming based on running apps

### Multi-monitor Note

`CGSCopyManagedDisplaySpaces` returns Spaces grouped by display. NameStore maps Space UUIDs regardless of display, so multi-monitor will work without schema changes when added later. MVP targets single-display only for testing and UI.

## Architecture

### Technology Stack

- **Language**: Swift
- **Framework**: AppKit as foundation, SwiftUI for views (popovers, settings)
- **Target**: macOS 15 (Sequoia) and later
- **Build**: Xcode project
- **Distribution**: Direct download (GitHub Releases), signed and notarized with Developer ID. Not eligible for Mac App Store due to private API usage.

### Components

#### 1. App Shell (`AppDelegate`)

- `NSApplication` configured as a menu bar-only app (LSUIElement = true, no Dock icon)
- Owns the `NSStatusItem` (menu bar item)
- Coordinates between SpaceDetector and NameStore
- Registers SMAppService for launch-at-login

#### 2. SpaceDetector

Responsible for detecting the current Space and tracking switches.

- Uses `CGSCopyManagedDisplaySpaces` (private API from SkyLight framework) to enumerate all Spaces and get their IDs
- Uses `CGSGetActiveSpace` (private API) to identify the currently active Space
- Listens to `NSWorkspace.activeSpaceDidChangeNotification` for switch events
- Re-enumerates Spaces on each notification to detect added/removed Spaces
- Provides: current Space ID, total Space count, ordered list of Space IDs

**Active Space detection**: `CGSGetActiveSpace` returns the Space ID of the currently focused Space. Combined with `CGSCopyManagedDisplaySpaces` for the full list, this gives us both enumeration and identification.

**Private API usage**: `CGSCopyManagedDisplaySpaces` and `CGSGetActiveSpace` are undocumented but widely used by popular macOS tools (yabai, Amethyst, AeroSpace). Confirmed working on macOS 15 Sequoia without disabling SIP.

#### 3. NameStore

Manages the mapping of Space IDs to user-defined names.

- Backed by `UserDefaults` (simple key-value storage)
- **Primary key**: Space UUID string (as returned by `CGSCopyManagedDisplaySpaces`)
- **Positional fallback**: Space UUIDs are generally stable on macOS 15 across reboots, but can change when Spaces are added/removed. If a stored UUID is no longer found in the current Space list, NameStore attempts positional matching (same index in the ordered list) and prompts the user to confirm.
- Falls back to "Desktop N" when no custom name is set
- Provides read/write access to names

#### 4. MenuBarController

Manages the menu bar UI.

- Creates and updates the `NSStatusItem` with the current desktop name (max 20 chars, truncated with ellipsis)
- Builds an `NSMenu` dropdown listing all desktops with a checkmark on the active one
- Each menu item has a "Rename..." action that opens an `NSPopover` with an `NSTextField`
- Refreshes on Space change notifications

### Data Flow

```
Space switch detected (NSWorkspace notification)
  -> SpaceDetector calls CGSGetActiveSpace to get current Space ID
  -> SpaceDetector calls CGSCopyManagedDisplaySpaces to refresh Space list
  -> NameStore looks up custom name for the active Space ID
  -> MenuBarController updates NSStatusItem title
```

### Permissions

- **Screen Recording**: required on macOS 15 for `CGSCopyManagedDisplaySpaces` to return Space information. The app will prompt the user on first launch and show a clear explanation of why this permission is needed.
- **Accessibility**: not required for the MVP approach.

### Storage

Desktop names stored in UserDefaults:

```
Key: "desktop_names"
Value: Dictionary<String, String>  // Space UUID -> custom name
```

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Private API breaks in future macOS | App stops detecting Spaces | Monitor macOS betas, maintain fallback detection |
| Permission requirements change | App needs new entitlements | Document required permissions clearly for users |
| Space UUIDs change when adding/removing Spaces | Names shift to wrong desktops | Positional fallback with user confirmation |
| Menu bar space exhaustion | Name not visible with many menu bar items | Truncate to 20 chars, consider icon-only mode later |
| macOS tightens private API access further | App may stop working without SIP disabled | Track macOS release notes, explore Accessibility API alternatives |

## Success Criteria

- App shows correct desktop name in menu bar at all times
- Switching desktops updates the name within 1 second
- Names persist across app restarts
- User can rename any desktop via the popover
- App launches at login without user intervention (after initial setup)
