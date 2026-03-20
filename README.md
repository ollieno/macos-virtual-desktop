# VirtualDesktop

A lightweight macOS menu bar utility for naming and visually identifying your virtual desktops (Spaces).

macOS gives you multiple desktops but no easy way to tell them apart. VirtualDesktop fixes that by showing the current desktop name in the menu bar, displaying a HUD overlay on switch, and optionally adding colored screen borders and persistent identifiers.

## Features

- **Menu bar label** showing the current desktop number and name (e.g. `2:Email`)
- **HUD overlay** that briefly appears on every desktop switch
- **Colored screen borders** to visually distinguish desktops at a glance (toggleable)
- **Desktop identifier** with a large persistent label behind your windows (toggleable)
- **Custom naming** for each desktop via double-click on the menu bar item or the dropdown menu
- **Reset all names** back to defaults (Desktop 1, Desktop 2, ...) in one click
- **Multi-monitor support** for overlays, borders, and identifiers on all screens
- **Launch at Login** option
- 10 distinct colors that cycle across desktops

## Requirements

- macOS 15.0 (Sequoia) or later
- Screen Recording permission (needed to detect virtual desktops via private APIs)

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/ollieno/macos-virtual-desktop/releases)
2. Drag **VirtualDesktop.app** to your Applications folder
3. Open the app. Since it is not notarized, right-click the app and choose **Open** the first time
4. Grant Screen Recording permission when prompted (System Settings > Privacy & Security > Screen Recording)

## Usage

| Action | How |
|---|---|
| See current desktop | Look at the menu bar label |
| Rename a desktop | Double-click the menu bar label, or single-click and choose a desktop from the menu |
| Toggle border colors | Menu > Show Border Colors |
| Toggle desktop identifier | Menu > Show Desktop Identifier |
| Reset all names | Menu > Reset Desktop Names |
| Launch at login | Menu > Launch at Login |
| Quit | Menu > Quit VirtualDesktop (or Cmd+Q) |

## Building from source

```bash
# Clone the repository
git clone https://github.com/ollieno/macos-virtual-desktop.git
cd macos-virtual-desktop

# Build (Debug)
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build

# Run tests
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test

# Build a distributable DMG (requires: brew install create-dmg)
./scripts/build-dmg.sh
```

## How it works

VirtualDesktop uses undocumented SkyLight framework APIs (via `dlsym`) to detect virtual desktop UUIDs and space changes. There is no public macOS API for this. The app runs as a menu bar-only utility (no Dock icon) and is not sandboxed, which is required for SkyLight access.

Desktop names are stored in UserDefaults as a UUID-to-name mapping. When macOS reassigns desktop UUIDs (e.g. after adding or removing a desktop), the app detects stale UUIDs on launch and offers to migrate names by position.

## License

Copyright 2026 Jeroen Olthof. All rights reserved.
