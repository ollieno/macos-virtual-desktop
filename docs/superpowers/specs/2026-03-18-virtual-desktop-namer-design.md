# VirtualDesktop: macOS Space Namer

## Problem

macOS Spaces (virtual desktops) only show generic names like "Desktop 1", "Desktop 2" in Mission Control. When working with 10+ desktops and frequently switching between them, there is no way to quickly identify which desktop serves which purpose.

## Solution

A native macOS menu bar app that lets users assign custom names to their Spaces and always shows the current desktop's name.

## MVP Scope

### Features

1. **Menu bar item** showing the current desktop's custom name (e.g. "Code", "Email", "Design")
2. **Dropdown menu** listing all desktops with their names
3. **Inline rename**: click a desktop name in the dropdown to edit it
4. **Auto-detect desktop switches** and update the displayed name
5. **Persist names** across app restarts

### Out of Scope (future)

- Overlay notification on desktop switch (like macOS volume indicator)
- Keyboard shortcuts to jump to a desktop by name
- Multi-monitor support
- Automatic naming based on running apps

## Architecture

### Technology Stack

- **Language**: Swift
- **Framework**: AppKit as foundation, SwiftUI for views (popovers, settings)
- **Target**: macOS 15 (Sequoia) and later
- **Build**: Xcode project

### Components

#### 1. App Shell (`AppDelegate`)

- `NSApplication` configured as a menu bar-only app (LSUIElement = true, no Dock icon)
- Owns the `NSStatusItem` (menu bar item)
- Coordinates between SpaceDetector and NameStore

#### 2. SpaceDetector

Responsible for detecting the current Space and tracking switches.

- Uses `CGSCopyManagedDisplaySpaces` (private API from SkyLight framework) to enumerate Spaces and get their IDs
- Listens to `NSWorkspace.activeSpaceDidChangeNotification` for switch events
- Provides: current Space ID, total Space count, ordered list of Space IDs

**Private API usage**: `CGSCopyManagedDisplaySpaces` is undocumented but widely used by popular macOS tools (yabai, Amethyst, AeroSpace). It returns an array of display dictionaries, each containing a "Spaces" array with Space IDs and properties.

#### 3. NameStore

Manages the mapping of Space IDs to user-defined names.

- Backed by `UserDefaults` (simple key-value storage)
- Maps Space UUID strings to custom names
- Falls back to "Desktop N" when no custom name is set
- Provides read/write access to names

#### 4. MenuBarController

Manages the menu bar UI.

- Creates and updates the `NSStatusItem` with the current desktop name
- Builds an `NSMenu` dropdown listing all desktops
- Handles click-to-rename via an editable `NSTextField` in the menu item
- Refreshes on Space change notifications

### Data Flow

```
Space switch detected (NSWorkspace notification)
  -> SpaceDetector identifies current Space ID
  -> NameStore looks up custom name for that ID
  -> MenuBarController updates NSStatusItem title
```

### Permissions

- **Accessibility**: may be needed depending on the approach for Space detection
- **Screen Recording**: `CGSCopyManagedDisplaySpaces` may require this permission on newer macOS versions

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
| Space UUIDs change on reboot | Names lost after restart | Detect and offer re-mapping, or use positional fallback |

## Success Criteria

- App shows correct desktop name in menu bar at all times
- Switching desktops updates the name within 1 second
- Names persist across app restarts
- User can rename any desktop via the dropdown menu
