# Mission Control Desktop Identifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent label window per desktop that shows the desktop name in Mission Control.

**Architecture:** New `IdentifierWindow.swift` follows the existing `BorderWindow.swift` pattern: SwiftUI view + NSPanel subclass + controller. The controller manages one panel per screen at a low window level so it sits behind all app windows. `Settings` gets a new toggle, `MenuBarController` integrates the controller.

**Tech Stack:** Swift, SwiftUI, AppKit (NSPanel)

**Note:** New files (`IdentifierWindow.swift`, `SettingsTests.swift`) must be added to the Xcode project (`project.pbxproj`). Either add them via Xcode or update `project.pbxproj` directly. Each task that creates a file includes a step for this.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `VirtualDesktop/UI/IdentifierWindow.swift` | Create | `IdentifierView` (SwiftUI), `IdentifierPanel` (NSPanel), `IdentifierController` |
| `VirtualDesktop/Services/Settings.swift` | Modify | Add `showIdentifier` property and `toggleIdentifier()` |
| `VirtualDesktop/UI/MenuBarController.swift` | Modify | Add identifier controller, toggle menu item, update on space change |
| `VirtualDesktopTests/SettingsTests.swift` | Create | Tests for new Settings property |

---

### Task 1: Add `showIdentifier` setting

**Files:**
- Modify: `VirtualDesktop/Services/Settings.swift`
- Create: `VirtualDesktopTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing test**

In `VirtualDesktopTests/SettingsTests.swift`:

```swift
import XCTest
@testable import VirtualDesktop

final class SettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "showIdentifier")
    }

    func testShowIdentifierDefaultsToTrue() {
        XCTAssertTrue(Settings.showIdentifier)
    }

    func testToggleIdentifier() {
        Settings.toggleIdentifier()
        XCTAssertFalse(Settings.showIdentifier)
        Settings.toggleIdentifier()
        XCTAssertTrue(Settings.showIdentifier)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -destination 'platform=macOS' -only-testing:VirtualDesktopTests/SettingsTests 2>&1 | tail -20`
Expected: FAIL (showIdentifier does not exist)

- [ ] **Step 3: Write minimal implementation**

In `VirtualDesktop/Services/Settings.swift`, add inside `enum Settings`:

```swift
static var showIdentifier: Bool {
    get { defaults.object(forKey: "showIdentifier") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "showIdentifier") }
}

static func toggleIdentifier() {
    showIdentifier = !showIdentifier
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -destination 'platform=macOS' -only-testing:VirtualDesktopTests/SettingsTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/Settings.swift VirtualDesktopTests/SettingsTests.swift
git commit -m "feat: add showIdentifier setting with toggle"
```

---

### Task 2: Create IdentifierWindow.swift

**Files:**
- Create: `VirtualDesktop/UI/IdentifierWindow.swift`

This task creates the SwiftUI view, NSPanel subclass, and controller. The pattern mirrors `BorderWindow.swift` exactly but with different window properties and content.

- [ ] **Step 1: Create `IdentifierView` (SwiftUI)**

Create `VirtualDesktop/UI/IdentifierWindow.swift`:

```swift
import Cocoa
import SwiftUI

// MARK: - SwiftUI view

private struct IdentifierView: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.system(size: 48, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 700, height: 200)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 15/255, green: 15/255, blue: 20/255).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}
```

- [ ] **Step 2: Add `IdentifierPanel` (NSPanel subclass)**

Append to the same file:

```swift
// MARK: - Single identifier panel

private final class IdentifierPanel: NSPanel {
    private var hostingView: NSHostingView<IdentifierView>?

    init(screen: NSScreen) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
    }

    func update(name: String, color: Color, on screen: NSScreen) {
        let view = IdentifierView(name: name, color: color)
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.translatesAutoresizingMaskIntoConstraints = false
            contentView = hv
            hostingView = hv
        }

        let size = NSSize(width: 700, height: 200)
        setContentSize(size)

        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.midY - size.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))

        orderFrontRegardless()
    }
}
```

- [ ] **Step 3: Add `IdentifierController`**

Append to the same file:

```swift
// MARK: - Identifier controller (manages one panel per screen)

final class IdentifierController {
    private var panels: [IdentifierPanel] = []

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
        }
    }

    func update(name: String, index: Int) {
        let screens = NSScreen.screens
        let color = DesktopColors.color(forIndex: index)

        while panels.count < screens.count {
            panels.append(IdentifierPanel(screen: screens[panels.count]))
        }

        for (i, screen) in screens.enumerated() {
            panels[i].update(name: name, color: color, on: screen)
        }

        for i in screens.count..<panels.count {
            panels[i].orderOut(nil)
        }
    }
}
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild build -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/UI/IdentifierWindow.swift
git commit -m "feat: add IdentifierWindow with panel and controller"
```

---

### Task 3: Integrate into MenuBarController

**Files:**
- Modify: `VirtualDesktop/UI/MenuBarController.swift`

- [ ] **Step 1: Add identifier controller property**

In `MenuBarController`, add alongside existing `border` property:

```swift
private let identifier = IdentifierController()
```

- [ ] **Step 2: Add `updateIdentifier()` method**

Add below the existing `updateBorder()` method:

```swift
private func updateIdentifier() {
    let uuid = spaceDetector.activeSpaceUUID()
    let index = spaceDetector.activeSpaceIndex()
    if Settings.showIdentifier {
        let name = nameStore.displayName(forSpaceID: uuid, atIndex: index)
        identifier.update(name: name, index: index)
    } else {
        identifier.hide()
    }
}
```

- [ ] **Step 3: Call `updateIdentifier()` from existing hooks**

Add `self.updateIdentifier()` call in two places:

1. In `init`, after `updateBorder()`:
```swift
updateIdentifier()
```

2. In the `observeSpaceChanges` closure, after `self.updateBorder()`:
```swift
self.updateIdentifier()
```

- [ ] **Step 4: Add menu toggle item**

In `populateMenu(_:)`, after the `borderItem` block and before the separator, add:

```swift
let identifierItem = NSMenuItem(
    title: "Show Desktop Identifier",
    action: #selector(toggleIdentifier(_:)),
    keyEquivalent: ""
)
identifierItem.target = self
identifierItem.state = Settings.showIdentifier ? .on : .off
menu.addItem(identifierItem)
```

- [ ] **Step 5: Add toggle action**

Add below `toggleBorderColors(_:)`:

```swift
@objc private func toggleIdentifier(_ sender: NSMenuItem) {
    Settings.toggleIdentifier()
    sender.state = Settings.showIdentifier ? .on : .off
    updateIdentifier()
}
```

- [ ] **Step 6: Update identifier on rename**

In `showRenamePopover(forUUID:atIndex:)`, inside the `onRename` closure, after `self?.updateTitle()`, add:

```swift
self?.updateIdentifier()
```

- [ ] **Step 7: Verify it compiles**

Run: `xcodebuild build -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Run all tests**

Run: `xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 9: Commit**

```bash
git add VirtualDesktop/UI/MenuBarController.swift
git commit -m "feat: integrate desktop identifier into menu bar controller"
```

---

### Task 4: Manual verification

- [ ] **Step 1: Build and run the app**

Run: `xcodebuild build -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -destination 'platform=macOS' 2>&1 | tail -10`
Then launch the app manually.

- [ ] **Step 2: Verify identifier window appears**

1. Check that the label window is visible on an empty desktop (or behind app windows)
2. Switch desktops and verify the label updates with correct name and color
3. Open Mission Control and verify the label is visible as a separate window thumbnail

- [ ] **Step 3: Verify toggle works**

1. Open the menu bar menu
2. Click "Show Desktop Identifier" to toggle off
3. Verify the label window disappears
4. Toggle back on and verify it reappears

- [ ] **Step 4: Verify rename updates identifier**

1. Double-click the menu bar item to rename
2. Enter a new name
3. Verify the identifier window text updates immediately
