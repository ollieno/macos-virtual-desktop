# VirtualDesktop Distribution-Ready Design

## Goal

Make VirtualDesktop ready to share with colleagues as a polished, installable macOS app distributed via DMG.

## Constraints

- No Apple Developer signing or notarization. Recipients will need to bypass Gatekeeper once.
- No changes to existing app functionality.
- English-language README.
- macOS 15.0 (Sequoia) minimum.

## 1. About Screen

### Location

New menu item "About VirtualDesktop" at the top of the existing menu bar menu (standard macOS convention), separated from the rest by a divider.

### Implementation

A SwiftUI view (`AboutView.swift`) presented in a standard `NSWindow`. The window is non-resizable, centered on screen, and closable.

### Content (top to bottom)

1. **App icon** - large, centered (128x128)
2. **App name** - "VirtualDesktop" in bold
3. **Version** - read from bundle: "Version 1.0.0 (Build 1)"
4. **Description** - "Name your virtual desktops, see colored borders per desktop, and identify desktops in Mission Control."
5. **Copyright** - "Copyright 2026 Jeroen. All rights reserved."
6. **Credits** - "Built with Swift and SwiftUI"
7. **Changelog** - "1.0.0: Initial release with desktop naming, colored borders, and Mission Control identifiers."

### Style

Standard macOS About window aesthetic: centered layout, light/dark mode compatible, system font. No custom styling.

### Integration

- `MenuBarController` gets an "About VirtualDesktop" item at position 0, followed by a separator.
- The About window is managed as a singleton to prevent multiple instances.

## 2. README

### Format

RTF file included in the DMG alongside the app and Applications symlink. Visible when the user opens the DMG.

### Content

1. **What is VirtualDesktop?** - brief description of features (naming desktops, colored borders, Mission Control identifiers, menu bar integration)
2. **Installation** - drag to Applications
3. **First launch** - Gatekeeper bypass instructions (right-click > Open > Open)
4. **Accessibility permission** - the app needs Accessibility access; explain how to grant it in System Settings > Privacy & Security > Accessibility
5. **Usage** - how to rename desktops (double-click menu bar item), toggle borders and identifiers, launch at login
6. **System requirements** - macOS 15.0 (Sequoia) or later

### Language

English.

## 3. DMG Build Script

### Location

`scripts/build-dmg.sh`

### Prerequisites

- Xcode (with command line tools)
- `create-dmg` (installed via `brew install create-dmg`)

### Steps

1. Clean and build the app with `xcodebuild` in Release configuration.
2. Copy the built `.app` bundle to a staging directory.
3. Copy `README.rtf` to the staging directory.
4. Run `create-dmg` to produce the DMG with:
   - The `.app` bundle
   - A symlink to `/Applications`
   - The README file
   - Window size and icon positions configured for a clean layout
   - App icon as DMG volume icon
5. Output: `build/VirtualDesktop-1.0.0.dmg`

### Version

The script reads the version from the app's Info.plist to name the DMG file.

## Files Changed / Added

| File | Action | Purpose |
|------|--------|---------|
| `VirtualDesktop/UI/AboutView.swift` | Add | SwiftUI About screen |
| `VirtualDesktop/UI/MenuBarController.swift` | Modify | Add "About" menu item |
| `README.rtf` | Add | User-facing documentation in DMG |
| `scripts/build-dmg.sh` | Add | DMG build automation |

## Out of Scope

- Code signing and notarization (can be added later)
- GitHub repository or release automation
- Sparkle or other auto-update frameworks
- Changes to existing app behavior
