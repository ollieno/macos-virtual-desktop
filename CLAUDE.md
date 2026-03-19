# VirtualDesktop

macOS menu bar utility for naming and visually identifying virtual desktops. Uses private SkyLight framework APIs. Not sandboxed.

## Build

```bash
# Debug build
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build

# Run tests
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test
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

## Project structure

- `VirtualDesktop/App/` - AppDelegate, main entry point
- `VirtualDesktop/Services/` - PrivateAPIs, SpaceDetector, NameStore, Settings, LaunchAtLogin
- `VirtualDesktop/UI/` - MenuBarController, OverlayWindow, BorderWindow, IdentifierWindow, AboutView, RenamePopover, DesktopColors
- `VirtualDesktopTests/` - Unit tests
- `scripts/build-dmg.sh` - DMG packaging script

## Versioning

Version is managed in `VirtualDesktop/Info.plist` (single source of truth):
- `CFBundleShortVersionString`: semver (e.g. 1.0.0)
- `CFBundleVersion`: incrementing build number

The build script handles bumping both when given a version argument.
