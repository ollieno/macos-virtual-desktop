# VirtualDesktop Distribution-Ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make VirtualDesktop distributable to colleagues via DMG with an About screen and README.

**Architecture:** Three independent additions: (1) SwiftUI About screen integrated into the existing menu, (2) RTF README at repo root for inclusion in DMG, (3) shell script that builds a Release .app and packages it into a DMG using create-dmg.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, create-dmg (Homebrew), xcodebuild

**Spec:** `docs/superpowers/specs/2026-03-19-distribution-ready-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `VirtualDesktop/UI/AboutView.swift` | Create | SwiftUI About screen view + NSWindow wrapper |
| `VirtualDesktop/UI/MenuBarController.swift` | Modify | Add About menu item, hold About window reference |
| `README.rtf` | Create | User-facing documentation included in DMG |
| `scripts/build-dmg.sh` | Create | Automated Release build + DMG packaging |
| `scripts/` | Create | Directory for build scripts (does not exist yet) |

---

## Task 1: About Screen View

**Files:**
- Create: `VirtualDesktop/UI/AboutView.swift`

- [ ] **Step 1: Create AboutView.swift with the SwiftUI view**

```swift
import SwiftUI

struct AboutView: View {
    private let appVersion: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(version) (Build \(build))"
    }()

    private let copyright: String = {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }()

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("VirtualDesktop")
                .font(.system(size: 20, weight: .bold))

            Text(appVersion)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Name your virtual desktops, see colored borders per desktop, and identify desktops in Mission Control.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Text(copyright)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text("Built with Swift and SwiftUI")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            Text("1.0.0: Initial release with desktop naming, colored borders, and Mission Control identifiers.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 340)
    }
}
```

- [ ] **Step 2: Add the AboutWindowController class in the same file**

Below `AboutView`, add:

```swift
final class AboutWindowController {
    private var window: NSWindow?

    func showAbout() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About VirtualDesktop"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Bring app to front (it's an LSUIElement app)
        NSApp.activate()

        self.window = window
    }
}
```

- [ ] **Step 3: Build to verify no compile errors**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add VirtualDesktop/UI/AboutView.swift
git commit -m "feat: add About screen with version, credits, and changelog"
```

---

## Task 2: Integrate About into Menu

**Files:**
- Modify: `VirtualDesktop/UI/MenuBarController.swift`

- [ ] **Step 1: Add aboutController property to MenuBarController**

After the `identifier` property (line 13), add:

```swift
private let aboutController = AboutWindowController()
```

- [ ] **Step 2: Add About menu item in populateMenu**

At the beginning of `populateMenu(_:)` (after `menu.removeAllItems()` on line 117), insert:

```swift
let aboutItem = NSMenuItem(
    title: "About VirtualDesktop",
    action: #selector(showAbout(_:)),
    keyEquivalent: ""
)
aboutItem.target = self
menu.addItem(aboutItem)
menu.addItem(NSMenuItem.separator())
```

- [ ] **Step 3: Add the showAbout action method**

In the `// MARK: - Actions` section, add:

```swift
@objc private func showAbout(_ sender: NSMenuItem) {
    aboutController.showAbout()
}
```

- [ ] **Step 4: Build to verify no compile errors**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run existing tests to verify nothing is broken**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test 2>&1 | tail -10`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add VirtualDesktop/UI/MenuBarController.swift
git commit -m "feat: add About menu item to menu bar"
```

---

## Task 3: README.rtf

**Files:**
- Create: `README.rtf` (repo root)

- [ ] **Step 1: Create README.rtf**

Create an RTF file at the repo root with the following content. Use a simple RTF structure with headers and body text:

```rtf
{\rtf1\ansi\ansicpg1252\cocoartf2820
{\fonttbl\f0\fswiss\fcharset0 Helvetica-Bold;\f1\fswiss\fcharset0 Helvetica;\f2\fswiss\fcharset0 Helvetica-Oblique;}
{\colortbl;\red255\green255\blue255;\red40\green40\blue40;}
\paperw11900\paperh16840\margl1440\margr1440\vieww12000\viewh15840
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs36 \cf2 VirtualDesktop\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 A macOS menu bar utility for naming and visually identifying your virtual desktops.\
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs28 \cf2 What does it do?\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 \bullet  Name your virtual desktops (e.g. "Code", "Email", "Design")\
\bullet  See the current desktop name in your menu bar\
\bullet  Colored borders around your screen edge per desktop\
\bullet  Large desktop identifiers visible in Mission Control\
\bullet  Quick rename by double-clicking the menu bar item\
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs28 \cf2 Installation\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 Drag \f0\b VirtualDesktop.app\f1\b0  to your \f0\b Applications\f1\b0  folder.\
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs28 \cf2 First Launch\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 This app is not signed with an Apple Developer certificate. On first launch, macOS will block it. To open it:\
\
1. Right-click (or Control-click) on VirtualDesktop.app in Applications\
2. Select \f0\b Open\f1\b0  from the context menu\
3. Click \f0\b Open\f1\b0  in the dialog that appears\
\
You only need to do this once.\
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs28 \cf2 Accessibility Permission\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 VirtualDesktop needs Accessibility access to detect your virtual desktops. When prompted:\
\
1. Open \f0\b System Settings\f1\b0  > \f0\b Privacy & Security\f1\b0  > \f0\b Accessibility\f1\b0\
2. Enable VirtualDesktop in the list\
\
If the app cannot detect desktops, it will show an alert with a direct link to the right settings page.\
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs28 \cf2 Usage\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 \bullet  \f0\b Rename a desktop:\f1\b0  Double-click the menu bar item, or click it once and select a desktop from the list\
\bullet  \f0\b Toggle colored borders:\f1\b0  Click the menu bar item > Show Border Colors\
\bullet  \f0\b Toggle Mission Control identifiers:\f1\b0  Click the menu bar item > Show Desktop Identifier\
\bullet  \f0\b Launch at login:\f1\b0  Click the menu bar item > Launch at Login\
\pard\tx566\pardeftab720\sa320\partightenfactor0

\f0\b\fs28 \cf2 System Requirements\
\pard\tx566\pardeftab720\sa240\partightenfactor0

\f1\b0\fs24 \cf2 macOS 15.0 (Sequoia) or later.\
}
```

- [ ] **Step 2: Commit**

```bash
git add README.rtf
git commit -m "docs: add README.rtf for DMG distribution"
```

---

## Task 4: DMG Build Script

**Files:**
- Create: `scripts/build-dmg.sh`

Note: `build/` is already in `.gitignore`. The `scripts/` directory does not exist yet and must be created.

- [ ] **Step 1: Create scripts directory and build-dmg.sh**

Run: `mkdir -p scripts`, then create `scripts/build-dmg.sh` with:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
STAGING_DIR="$BUILD_DIR/staging"
APP_NAME="VirtualDesktop"

# Check prerequisites
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Install Xcode and command line tools." >&2
    exit 1
fi

if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg" >&2
    exit 1
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR"

echo "Building $APP_NAME (Release)..."
xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/derived" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | tail -3

# Find the built app
APP_PATH="$BUILD_DIR/derived/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built app not found at $APP_PATH" >&2
    exit 1
fi

# Read version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Staging DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
cp "$PROJECT_DIR/README.rtf" "$STAGING_DIR/"

echo "Creating DMG: $DMG_NAME..."
VOLICON_ARGS=()
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    VOLICON_ARGS=(--volicon "$APP_PATH/Contents/Resources/AppIcon.icns")
fi

create-dmg \
    --volname "$APP_NAME" \
    "${VOLICON_ARGS[@]}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 80 \
    --icon "$APP_NAME.app" 160 190 \
    --app-drop-link 440 190 \
    --icon "README.rtf" 300 340 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGING_DIR"

# Clean up staging
rm -rf "$STAGING_DIR"
rm -rf "$BUILD_DIR/derived"

echo ""
echo "Done! DMG created at: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/build-dmg.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/build-dmg.sh
git commit -m "feat: add DMG build script for distribution"
```

---

## Task 5: Build and Verify DMG

- [ ] **Step 1: Ensure create-dmg is installed**

Run: `brew install create-dmg` (skip if already installed)

- [ ] **Step 2: Run the build script**

Run: `./scripts/build-dmg.sh`
Expected: Script completes with "Done! DMG created at: build/VirtualDesktop-1.0.0.dmg"

- [ ] **Step 3: Verify the DMG contents**

Run: `hdiutil attach build/VirtualDesktop-1.0.0.dmg -nobrowse`
Then: `ls /Volumes/VirtualDesktop/`
Expected: `VirtualDesktop.app`, `Applications` (symlink), `README.rtf`
Cleanup: `hdiutil detach /Volumes/VirtualDesktop`

- [ ] **Step 4: Verify the app launches from the DMG**

Run the app from the mounted DMG volume manually. Verify:
- Menu bar item appears
- Click shows menu with "About VirtualDesktop" at top
- About window opens and shows correct version, description, credits, changelog
- About window closes properly
- Existing functionality (borders, identifiers, renaming) still works

- [ ] **Step 5: Final commit if any adjustments were needed**

Only if changes were made during verification.
