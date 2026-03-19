# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
# Debug build
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build

# Run all tests
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test

# Run a single test class
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/NameStoreTests
```

## Distribution

```bash
# Build DMG with current version
./scripts/build-dmg.sh

# Build DMG with version bump (bumps Info.plist, commits, then builds)
./scripts/build-dmg.sh 1.1.0
```

Output: `build/VirtualDesktop-<version>.dmg`

Requires: `brew install create-dmg`

The app is not signed or notarized. Recipients bypass Gatekeeper via right-click > Open.

## Versioning

Version is managed in `VirtualDesktop/Info.plist` (single source of truth):
- `CFBundleShortVersionString`: semver (e.g. 1.0.0)
- `CFBundleVersion`: incrementing build number

The build script handles bumping both when given a version argument.

## Architecture

macOS menu bar utility (LSUIElement, no Dock icon) for naming and visually identifying virtual desktops. Swift 5.10, SwiftUI views hosted in AppKit windows. Minimum macOS 15.0.

### Data flow

`PrivateAPIs` (SkyLight dlsym) -> `SpaceDetector` (space change notifications) -> `MenuBarController` (coordinates all UI)

On desktop switch, `SpaceDetector` posts `activeSpaceDidChange`. `MenuBarController` observes this and updates: menu bar title, overlay HUD, border color, Mission Control identifier.

### Key design decisions

- **Private APIs**: Uses undocumented SkyLight framework via `dlsym` to detect virtual desktops. There is no public API for this. The app requires Accessibility permission.
- **Not sandboxed**: Required for SkyLight access. Entitlements file has `app-sandbox: false`.
- **Desktop identification**: Desktops are identified by UUID (from SkyLight). UUIDs can change when desktops are added/removed. `AppDelegate` handles migration of stored names to new UUIDs on launch.
- **Name storage**: `NameStore` persists desktop names in UserDefaults as `[UUID: name]` dictionary under key `desktop_names`.
- **Multi-screen**: Overlay, border, and identifier windows are created per-screen.
- **Menu bar click handling**: Single-click opens menu, double-click opens rename popover. Uses a timer with `NSEvent.doubleClickInterval` to distinguish.

### XcodeGen

`project.yml` is the XcodeGen source, but `.xcodeproj` is committed. You do not need xcodegen to build. If you modify project settings, update both `project.yml` and regenerate with `xcodegen generate`.
