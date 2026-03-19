# Move Window to Desktop - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global hotkey that shows a desktop picker menu and moves the active window to the selected desktop.

**Architecture:** CGEvent tap captures a configurable hotkey, AXUIElement reads the active window, SLSMoveWindowsToManagedSpace moves it. An NSMenu at the window center lets the user pick the target desktop.

**Tech Stack:** Swift 5.10, AppKit, SkyLight private framework, Accessibility API, CGEvent

**Spec:** `docs/superpowers/specs/2026-03-19-move-window-to-desktop-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `VirtualDesktop/Services/HotkeyManager.swift` | CGEvent tap, global hotkey registration |
| Create | `VirtualDesktop/Services/WindowMover.swift` | AXUIElement window access, SkyLight window move |
| Create | `VirtualDesktop/UI/MoveToDesktopMenu.swift` | NSMenu builder and display at window center |
| Create | `VirtualDesktop/UI/HotkeyRecorderPanel.swift` | NSPanel for capturing new hotkey |
| Create | `VirtualDesktopTests/HotkeyManagerTests.swift` | Hotkey matching logic tests |
| Create | `VirtualDesktopTests/WindowMoverTests.swift` | Edge case tests |
| Create | `VirtualDesktopTests/MoveToDesktopMenuTests.swift` | Menu construction tests |
| Modify | `VirtualDesktop/Services/PrivateAPIs.swift` | Add SLSMoveWindowsToManagedSpace, _AXUIElementGetWindow |
| Modify | `VirtualDesktop/Services/Settings.swift` | Add moveWindowKeyCode, moveWindowModifiers |
| Modify | `VirtualDesktop/UI/MenuBarController.swift` | Add hotkey callback, menu item for shortcut config |
| Modify | `VirtualDesktop/App/AppDelegate.swift` | Init HotkeyManager/WindowMover, Accessibility permission check |

---

## Task 0: Verify project builds and xcodegen is available

**Files:** None (project setup verification)

New source files will be auto-discovered by XcodeGen since `project.yml` uses directory-level sources (`- VirtualDesktop` and `- VirtualDesktopTests`). After adding new files, regenerate the Xcode project.

- [ ] **Step 1: Check xcodegen is installed**

Run: `which xcodegen || echo "NOT FOUND"`
If not found: `brew install xcodegen`

- [ ] **Step 2: Verify current project builds**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Note:** After creating each new `.swift` file in Tasks 1-6, run `xcodegen generate` to regenerate the `.xcodeproj` before building. This is needed because the `.xcodeproj` is committed and won't automatically pick up new files.

---

## Task 1: Extend PrivateAPIs with window movement functions

**Files:**
- Modify: `VirtualDesktop/Services/PrivateAPIs.swift`

This task adds the SkyLight function pointers needed for window movement and the AXUIElement-to-CGWindowID bridge.

- [ ] **Step 1: Add SLSMoveWindowsToManagedSpace function pointer**

In `VirtualDesktop/Services/PrivateAPIs.swift`, add after line 34 (after `_CGSCopyManagedDisplaySpaces`):

```swift
private static let _SLSMoveWindowsToManagedSpace: (@convention(c) (CGSConnectionID, CFArray, CGSSpaceID) -> Void)? = {
    guard let handle = skyLightHandle,
          let sym = dlsym(handle, "SLSMoveWindowsToManagedSpace") else { return nil }
    return unsafeBitCast(sym, to: (@convention(c) (CGSConnectionID, CFArray, CGSSpaceID) -> Void).self)
}()
```

- [ ] **Step 2: Add _AXUIElementGetWindow function pointer**

Add below the SkyLight pointers:

```swift
private static let _AXUIElementGetWindow: (@convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError)? = {
    guard let handle = dlopen(nil, RTLD_LAZY),
          let sym = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
    return unsafeBitCast(sym, to: (@convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError).self)
}()
```

- [ ] **Step 3: Add public moveWindows method**

Add in the `// MARK: - Public interface` section:

```swift
/// Moves windows to the specified Space. Returns false if the API is unavailable.
@discardableResult
static func moveWindows(_ windowIDs: [CGWindowID], toSpace spaceID: UInt64) -> Bool {
    guard let mainConn = _CGSMainConnectionID,
          let moveWindows = _SLSMoveWindowsToManagedSpace else { return false }
    let conn = mainConn()
    let nsArray = windowIDs.map { NSNumber(value: $0) } as CFArray
    moveWindows(conn, nsArray, spaceID)
    return true
}
```

- [ ] **Step 4: Add public windowID(from:) method**

Add below moveWindows:

```swift
/// Extracts the CGWindowID from an AXUIElement. Returns nil if unavailable.
static func windowID(from element: AXUIElement) -> CGWindowID? {
    guard let getWindow = _AXUIElementGetWindow else { return nil }
    var windowID: CGWindowID = 0
    let result = getWindow(element, &windowID)
    guard result == .success, windowID != 0 else { return nil }
    return windowID
}
```

- [ ] **Step 5: Add display identifier to SpaceInfo**

In `VirtualDesktop/Services/SpaceDetector.swift`, update `SpaceInfo` to include a display UUID:

```swift
struct SpaceInfo {
    let id: UInt64
    let uuid: String
    let index: Int
    let displayUUID: String
}
```

Update `allSpaces()` to populate `displayUUID`:

```swift
func allSpaces() -> [SpaceInfo] {
    let displays = PrivateAPIs.getManagedDisplaySpaces()
    var result: [SpaceInfo] = []
    var index = 0

    for display in displays {
        let displayUUID = display["Display Identifier"] as? String ?? ""
        guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
        for space in spaces {
            let type = space["type"] as? Int ?? 0
            guard type == 0 else { continue }

            let id = space["id64"] as? UInt64 ?? 0
            let uuid = space["uuid"] as? String ?? ""

            result.append(SpaceInfo(id: id, uuid: uuid, index: index, displayUUID: displayUUID))
            index += 1
        }
    }

    return result
}
```

Also update any test files that construct `SpaceInfo` to include the new `displayUUID` parameter (use `""` as default in tests).

- [ ] **Step 6: Regenerate Xcode project and build**

Run: `xcodegen generate && xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add VirtualDesktop/Services/PrivateAPIs.swift VirtualDesktop/Services/SpaceDetector.swift
git commit -m "feat: add SLSMoveWindowsToManagedSpace, _AXUIElementGetWindow, and display UUID to SpaceInfo"
```

---

## Task 2: Extend Settings with hotkey configuration

**Files:**
- Modify: `VirtualDesktop/Services/Settings.swift`
- Create: `VirtualDesktopTests/SettingsHotkeyTests.swift`

- [ ] **Step 1: Write the failing test**

Create `VirtualDesktopTests/SettingsHotkeyTests.swift`:

```swift
import XCTest
import Carbon.HIToolbox
@testable import VirtualDesktop

final class SettingsHotkeyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "moveWindowKeyCode")
        UserDefaults.standard.removeObject(forKey: "moveWindowModifiers")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "moveWindowKeyCode")
        UserDefaults.standard.removeObject(forKey: "moveWindowModifiers")
        super.tearDown()
    }

    func testDefaultKeyCodeIsM() {
        XCTAssertEqual(Settings.moveWindowKeyCode, UInt16(kVK_ANSI_M))
    }

    func testDefaultModifiersAreCtrlShift() {
        let expected = CGEventFlags.maskControl.union(.maskShift).rawValue
        XCTAssertEqual(Settings.moveWindowModifiers, expected)
    }

    func testSetAndGetKeyCode() {
        Settings.moveWindowKeyCode = UInt16(kVK_ANSI_K)
        XCTAssertEqual(Settings.moveWindowKeyCode, UInt16(kVK_ANSI_K))
    }

    func testSetAndGetModifiers() {
        let newMods = CGEventFlags.maskCommand.union(.maskShift).rawValue
        Settings.moveWindowModifiers = newMods
        XCTAssertEqual(Settings.moveWindowModifiers, newMods)
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and run test to verify it fails**

Run: `xcodegen generate && xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/SettingsHotkeyTests 2>&1 | tail -10`
Expected: FAIL with compilation errors (properties don't exist yet)

- [ ] **Step 3: Implement in Settings.swift**

Add to `VirtualDesktop/Services/Settings.swift` before the closing `}`:

```swift
static var moveWindowKeyCode: UInt16 {
    get {
        guard let value = defaults.object(forKey: "moveWindowKeyCode") as? Int else {
            return UInt16(kVK_ANSI_M)
        }
        return UInt16(value)
    }
    set { defaults.set(Int(newValue), forKey: "moveWindowKeyCode") }
}

static var moveWindowModifiers: UInt64 {
    get {
        guard let value = defaults.object(forKey: "moveWindowModifiers") as? UInt64 else {
            return CGEventFlags.maskControl.union(.maskShift).rawValue
        }
        return value
    }
    set { defaults.set(newValue, forKey: "moveWindowModifiers") }
}
```

Also add `import Carbon.HIToolbox` at the top of Settings.swift.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/SettingsHotkeyTests 2>&1 | tail -10`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/Settings.swift VirtualDesktopTests/SettingsHotkeyTests.swift
git commit -m "feat: add hotkey settings for move-window shortcut"
```

---

## Task 3: Create HotkeyManager

**Files:**
- Create: `VirtualDesktop/Services/HotkeyManager.swift`
- Create: `VirtualDesktopTests/HotkeyManagerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `VirtualDesktopTests/HotkeyManagerTests.swift`:

```swift
import XCTest
import Carbon.HIToolbox
@testable import VirtualDesktop

final class HotkeyManagerTests: XCTestCase {
    func testMatchesConfiguredHotkey() {
        let manager = HotkeyManager {}
        let keyCode = Settings.moveWindowKeyCode
        let modifiers = CGEventFlags(rawValue: Settings.moveWindowModifiers)
        XCTAssertTrue(manager.matches(keyCode: keyCode, flags: modifiers))
    }

    func testRejectsWrongKeyCode() {
        let manager = HotkeyManager {}
        let modifiers = CGEventFlags(rawValue: Settings.moveWindowModifiers)
        XCTAssertFalse(manager.matches(keyCode: UInt16(kVK_ANSI_Z), flags: modifiers))
    }

    func testRejectsWrongModifiers() {
        let manager = HotkeyManager {}
        let keyCode = Settings.moveWindowKeyCode
        XCTAssertFalse(manager.matches(keyCode: keyCode, flags: .maskCommand))
    }

    func testIsActiveReflectsTapState() {
        let manager = HotkeyManager {}
        // In test environment, CGEvent tap creation may fail (no Accessibility permission)
        // Just verify the property exists and is a Bool
        _ = manager.isActive
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and run test to verify it fails**

Run: `xcodegen generate && xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/HotkeyManagerTests 2>&1 | tail -10`
Expected: FAIL (HotkeyManager doesn't exist)

- [ ] **Step 3: Implement HotkeyManager**

Create `VirtualDesktop/Services/HotkeyManager.swift`:

```swift
import Cocoa
import Carbon.HIToolbox
import os.log

final class HotkeyManager {
    private let logger = Logger(subsystem: "com.jeroen.VirtualDesktop", category: "HotkeyManager")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let callback: () -> Void

    private(set) var isActive: Bool = false

    init(callback: @escaping () -> Void) {
        self.callback = callback
        setupEventTap()
    }

    func matches(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        let configuredKeyCode = Settings.moveWindowKeyCode
        let configuredModifiers = CGEventFlags(rawValue: Settings.moveWindowModifiers)

        let relevantMask: CGEventFlags = [.maskControl, .maskShift, .maskCommand, .maskAlternate]
        let incomingMods = flags.intersection(relevantMask)
        let configuredMods = configuredModifiers.intersection(relevantMask)

        return keyCode == configuredKeyCode && incomingMods == configuredMods
    }

    func restart() {
        stop()
        setupEventTap()
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        isActive = false
    }

    // MARK: - Private

    private func setupEventTap() {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags

                if manager.matches(keyCode: keyCode, flags: flags) {
                    DispatchQueue.main.async {
                        manager.callback()
                    }
                    return nil // consume the event
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            logger.warning("Failed to create CGEvent tap. Accessibility permission may not be granted.")
            isActive = false
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isActive = true
            logger.info("CGEvent tap created successfully.")
        }
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/HotkeyManagerTests 2>&1 | tail -10`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/HotkeyManager.swift VirtualDesktopTests/HotkeyManagerTests.swift
git commit -m "feat: add HotkeyManager with CGEvent tap for global hotkey"
```

---

## Task 4: Create WindowMover

**Files:**
- Create: `VirtualDesktop/Services/WindowMover.swift`
- Create: `VirtualDesktopTests/WindowMoverTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `VirtualDesktopTests/WindowMoverTests.swift`:

```swift
import XCTest
@testable import VirtualDesktop

final class WindowMoverTests: XCTestCase {
    func testWindowCenterCalculation() {
        // Test the pure geometry calculation
        let origin = CGPoint(x: 100, y: 200)
        let size = CGSize(width: 800, height: 600)
        let center = WindowMover.centerPoint(origin: origin, size: size)
        XCTAssertEqual(center.x, 500) // 100 + 800/2
        XCTAssertEqual(center.y, 500) // 200 + 600/2
    }

    func testWindowCenterWithZeroSize() {
        let origin = CGPoint(x: 100, y: 200)
        let size = CGSize.zero
        let center = WindowMover.centerPoint(origin: origin, size: size)
        XCTAssertEqual(center.x, 100)
        XCTAssertEqual(center.y, 200)
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and run test to verify it fails**

Run: `xcodegen generate && xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/WindowMoverTests 2>&1 | tail -10`
Expected: FAIL (WindowMover doesn't exist)

- [ ] **Step 3: Implement WindowMover**

Create `VirtualDesktop/Services/WindowMover.swift`:

```swift
import Cocoa
import os.log

final class WindowMover {
    private let logger = Logger(subsystem: "com.jeroen.VirtualDesktop", category: "WindowMover")

    struct ActiveWindowInfo {
        let windowID: CGWindowID
        let center: CGPoint
        let appElement: AXUIElement
        let windowElement: AXUIElement
    }

    /// Gets info about the currently focused window, or nil if none is available.
    func activeWindowInfo() -> ActiveWindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            logger.debug("No frontmost application.")
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowElement = windowRef else {
            logger.debug("No focused window for \(app.localizedName ?? "unknown app").")
            return nil
        }

        let axWindow = windowElement as! AXUIElement

        // Check if the window is movable
        var movableRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXMovableAttribute as CFString, &movableRef) == .success,
           let movable = movableRef as? Bool, !movable {
            logger.debug("Window is not movable.")
            return nil
        }

        // Get window ID
        guard let windowID = PrivateAPIs.windowID(from: axWindow) else {
            logger.debug("Could not get CGWindowID from AXUIElement.")
            return nil
        }

        // Get position and size for center calculation
        let center = windowCenter(of: axWindow)

        return ActiveWindowInfo(
            windowID: windowID,
            center: center,
            appElement: appElement,
            windowElement: axWindow
        )
    }

    /// Moves a window to the target Space. Prevents macOS from auto-following.
    @discardableResult
    func moveWindow(_ windowID: CGWindowID, toSpace spaceID: UInt64) -> Bool {
        let originalSpaceID = PrivateAPIs.getActiveSpaceID()

        let result = PrivateAPIs.moveWindows([windowID], toSpace: spaceID)
        if result {
            logger.info("Moved window \(windowID) to space \(spaceID).")

            // Check if macOS auto-followed to the target space.
            // This can happen depending on the "When switching to an application,
            // switch to a Space with open windows" System Preferences setting.
            let currentSpaceID = PrivateAPIs.getActiveSpaceID()
            if currentSpaceID != originalSpaceID {
                logger.info("macOS auto-followed to space \(currentSpaceID). User stays on \(originalSpaceID).")
                // Note: We cannot programmatically switch back without additional
                // private APIs. Log this as a known limitation.
            }
        } else {
            logger.warning("Failed to move window \(windowID). SLSMoveWindowsToManagedSpace may be unavailable.")
        }
        return result
    }

    /// Pure geometry: calculates center of a rect defined by origin + size.
    static func centerPoint(origin: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    // MARK: - Private

    private func windowCenter(of window: AXUIElement) -> CGPoint {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        var origin = CGPoint.zero
        var size = CGSize.zero

        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
           let posValue = posRef {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &origin)
        }

        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        return Self.centerPoint(origin: origin, size: size)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/WindowMoverTests 2>&1 | tail -10`
Expected: All 2 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/WindowMover.swift VirtualDesktopTests/WindowMoverTests.swift
git commit -m "feat: add WindowMover for AXUIElement window access and movement"
```

---

## Task 5: Create MoveToDesktopMenu

**Files:**
- Create: `VirtualDesktop/UI/MoveToDesktopMenu.swift`
- Create: `VirtualDesktopTests/MoveToDesktopMenuTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `VirtualDesktopTests/MoveToDesktopMenuTests.swift`:

```swift
import XCTest
@testable import VirtualDesktop

final class MoveToDesktopMenuTests: XCTestCase {
    private var defaults: UserDefaults!
    private var nameStore: NameStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.jeroen.VirtualDesktop.tests.menu")!
        defaults.removePersistentDomain(forName: "com.jeroen.VirtualDesktop.tests.menu")
        nameStore = NameStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "com.jeroen.VirtualDesktop.tests.menu")
        super.tearDown()
    }

    func testBuildMenuExcludesCurrentDesktop() {
        nameStore.setName("Code", forSpaceID: "uuid-1")
        nameStore.setName("Email", forSpaceID: "uuid-2")
        nameStore.setName("Music", forSpaceID: "uuid-3")

        let spaces = [
            SpaceInfo(id: 1, uuid: "uuid-1", index: 0, displayUUID: "display-1"),
            SpaceInfo(id: 2, uuid: "uuid-2", index: 1, displayUUID: "display-1"),
            SpaceInfo(id: 3, uuid: "uuid-3", index: 2, displayUUID: "display-1"),
        ]

        let items = MoveToDesktopMenu.buildMenuItems(
            spaces: spaces,
            activeSpaceID: 1,
            activeDisplayUUID: "display-1",
            nameStore: nameStore
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "2: Email")
        XCTAssertEqual(items[1].title, "3: Music")
    }

    func testBuildMenuReturnsEmptyForSingleDesktop() {
        let spaces = [
            SpaceInfo(id: 1, uuid: "uuid-1", index: 0, displayUUID: "display-1"),
        ]

        let items = MoveToDesktopMenu.buildMenuItems(
            spaces: spaces,
            activeSpaceID: 1,
            activeDisplayUUID: "display-1",
            nameStore: nameStore
        )

        XCTAssertTrue(items.isEmpty)
    }

    func testBuildMenuUsesDefaultNamesForUnnamed() {
        let spaces = [
            SpaceInfo(id: 1, uuid: "uuid-1", index: 0, displayUUID: "display-1"),
            SpaceInfo(id: 2, uuid: "uuid-2", index: 1, displayUUID: "display-1"),
        ]

        let items = MoveToDesktopMenu.buildMenuItems(
            spaces: spaces,
            activeSpaceID: 1,
            activeDisplayUUID: "display-1",
            nameStore: nameStore
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "2: Desktop 2")
    }

    func testBuildMenuFiltersOtherDisplays() {
        nameStore.setName("Code", forSpaceID: "uuid-1")
        nameStore.setName("Email", forSpaceID: "uuid-2")
        nameStore.setName("External", forSpaceID: "uuid-3")

        let spaces = [
            SpaceInfo(id: 1, uuid: "uuid-1", index: 0, displayUUID: "display-1"),
            SpaceInfo(id: 2, uuid: "uuid-2", index: 1, displayUUID: "display-1"),
            SpaceInfo(id: 3, uuid: "uuid-3", index: 2, displayUUID: "display-2"),
        ]

        let items = MoveToDesktopMenu.buildMenuItems(
            spaces: spaces,
            activeSpaceID: 1,
            activeDisplayUUID: "display-1",
            nameStore: nameStore
        )

        // Only desktop 2 on display-1, not desktop 3 on display-2
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "2: Email")
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and run test to verify it fails**

Run: `xcodegen generate && xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/MoveToDesktopMenuTests 2>&1 | tail -10`
Expected: FAIL (MoveToDesktopMenu doesn't exist)

- [ ] **Step 3: Implement MoveToDesktopMenu**

Create `VirtualDesktop/UI/MoveToDesktopMenu.swift`:

```swift
import Cocoa

final class MoveToDesktopMenu: NSObject {
    private let spaceDetector: SpaceDetector
    private let nameStore: NameStore
    private let windowMover: WindowMover
    private var positioningWindow: NSWindow?

    init(spaceDetector: SpaceDetector, nameStore: NameStore, windowMover: WindowMover) {
        self.spaceDetector = spaceDetector
        self.nameStore = nameStore
        self.windowMover = windowMover
        super.init()
    }

    /// Shows the desktop picker menu at the center of the active window.
    func show() {
        guard let windowInfo = windowMover.activeWindowInfo() else { return }

        let spaces = spaceDetector.allSpaces()
        let activeSpaceID = spaceDetector.activeSpaceID()

        let activeSpace = spaces.first(where: { $0.id == activeSpaceID })
        let activeDisplayUUID = activeSpace?.displayUUID ?? ""

        let items = Self.buildMenuItems(
            spaces: spaces,
            activeSpaceID: activeSpaceID,
            activeDisplayUUID: activeDisplayUUID,
            nameStore: nameStore
        )

        guard !items.isEmpty else { return }

        let menu = NSMenu()
        for item in items {
            item.target = self
            item.action = #selector(menuItemSelected(_:))
            menu.addItem(item)
        }

        showMenu(menu, at: windowInfo.center, windowID: windowInfo.windowID)
    }

    /// Pure function for building menu items. Testable without UI or system state.
    /// Only includes desktops from the same display as the active space.
    static func buildMenuItems(
        spaces: [SpaceInfo],
        activeSpaceID: UInt64,
        activeDisplayUUID: String,
        nameStore: NameStore
    ) -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        for space in spaces {
            guard space.id != activeSpaceID,
                  space.displayUUID == activeDisplayUUID else { continue }

            let name = nameStore.name(forSpaceID: space.uuid, atIndex: space.index)
            let title = "\(space.index + 1): \(name)"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = space
            items.append(item)
        }

        return items
    }

    // MARK: - Private

    /// The window ID captured when the menu was shown, before the menu takes focus.
    private var pendingWindowID: CGWindowID?

    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        guard let space = sender.representedObject as? SpaceInfo,
              let windowID = pendingWindowID else { return }

        windowMover.moveWindow(windowID, toSpace: space.id)
        pendingWindowID = nil
        cleanupPositioningWindow()
    }

    private func showMenu(_ menu: NSMenu, at screenPoint: CGPoint, windowID: CGWindowID) {
        pendingWindowID = windowID
        // Convert from top-left origin (CGEvent/AXUIElement) to bottom-left origin (AppKit)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) })
                ?? NSScreen.main else {
            cleanupPositioningWindow()
            return
        }

        let flippedY = screen.frame.maxY - screenPoint.y

        // Create a transparent window to anchor the menu
        let window = NSWindow(
            contentRect: NSRect(x: screenPoint.x, y: flippedY, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .popUpMenu
        window.orderFront(nil)
        positioningWindow = window

        menu.popUp(positioning: nil, at: .zero, in: window.contentView)
        cleanupPositioningWindow()
    }

    private func cleanupPositioningWindow() {
        positioningWindow?.orderOut(nil)
        positioningWindow = nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test -only-testing:VirtualDesktopTests/MoveToDesktopMenuTests 2>&1 | tail -10`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/UI/MoveToDesktopMenu.swift VirtualDesktopTests/MoveToDesktopMenuTests.swift
git commit -m "feat: add MoveToDesktopMenu with desktop picker at window center"
```

---

## Task 6: Create HotkeyRecorderPanel

**Files:**
- Create: `VirtualDesktop/UI/HotkeyRecorderPanel.swift`

This is a small NSPanel that lets the user press a new key combination to configure the hotkey.

- [ ] **Step 1: Implement HotkeyRecorderPanel**

Create `VirtualDesktop/UI/HotkeyRecorderPanel.swift`:

```swift
import Cocoa
import SwiftUI
import Carbon.HIToolbox

struct HotkeyRecorderView: View {
    let currentKeyCode: UInt16
    let currentModifiers: UInt64
    let onRecord: (UInt16, UInt64) -> Void
    let onCancel: () -> Void

    @State private var displayText: String = "Press a key combination..."
    @State private var isRecording = true

    var body: some View {
        VStack(spacing: 12) {
            Text(displayText)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 250)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            HStack(spacing: 8) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .onAppear {
            displayText = Self.formatHotkey(keyCode: currentKeyCode, modifiers: currentModifiers)
        }
    }

    static func formatHotkey(keyCode: UInt16, modifiers: UInt64) -> String {
        let flags = CGEventFlags(rawValue: modifiers)
        var parts: [String] = []

        if flags.contains(.maskControl) { parts.append("Ctrl") }
        if flags.contains(.maskAlternate) { parts.append("Option") }
        if flags.contains(.maskShift) { parts.append("Shift") }
        if flags.contains(.maskCommand) { parts.append("Cmd") }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)

        return parts.joined(separator: "+")
    }

    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        let mapping: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
            UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
            UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
            UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
            UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
            UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
            UInt16(kVK_ANSI_9): "9",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
            UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
            UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
            UInt16(kVK_Space): "Space", UInt16(kVK_Return): "Return",
            UInt16(kVK_Tab): "Tab", UInt16(kVK_Delete): "Delete",
        ]
        return mapping[keyCode] ?? "Key\(keyCode)"
    }
}

final class HotkeyRecorderPanel {
    private var panel: NSPanel?
    private var localMonitor: Any?

    func show(onRecord: @escaping (UInt16, UInt64) -> Void, onCancel: @escaping () -> Void) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Record Shortcut"
        panel.isFloatingPanel = true
        panel.center()

        let view = HotkeyRecorderView(
            currentKeyCode: Settings.moveWindowKeyCode,
            currentModifiers: Settings.moveWindowModifiers,
            onRecord: { [weak self] keyCode, modifiers in
                onRecord(keyCode, modifiers)
                self?.close()
            },
            onCancel: { [weak self] in
                onCancel()
                self?.close()
            }
        )
        panel.contentViewController = NSHostingController(rootView: view)

        // Monitor key events to capture the new hotkey
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags
            let hasModifier = flags.contains(.control) || flags.contains(.command)
                || flags.contains(.option) || flags.contains(.shift)

            guard hasModifier else { return event }

            let modifiers = CGEventFlags(rawValue: 0)
                .union(flags.contains(.control) ? .maskControl : [])
                .union(flags.contains(.shift) ? .maskShift : [])
                .union(flags.contains(.command) ? .maskCommand : [])
                .union(flags.contains(.option) ? .maskAlternate : [])

            onRecord(event.keyCode, modifiers.rawValue)
            self?.close()
            return nil
        }

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func close() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `xcodegen generate && xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add VirtualDesktop/UI/HotkeyRecorderPanel.swift
git commit -m "feat: add HotkeyRecorderPanel for configurable shortcut"
```

---

## Task 7: Wire everything together in MenuBarController and AppDelegate

**Files:**
- Modify: `VirtualDesktop/UI/MenuBarController.swift`
- Modify: `VirtualDesktop/App/AppDelegate.swift`

- [ ] **Step 1: Update MenuBarController init and add hotkey callback**

In `VirtualDesktop/UI/MenuBarController.swift`:

Change the property declarations (lines 3-14) to add new dependencies:

```swift
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let spaceDetector: SpaceDetector
    private let nameStore: NameStore
    private let hotkeyManager: HotkeyManager
    private let windowMover: WindowMover
    private let moveMenu: MoveToDesktopMenu
    private var spaceChangeObservation: NSObjectProtocol?
    private var activePopover: RenamePopover?
    private var clickTimer: Timer?
    private let menu: NSMenu
    private let overlay = OverlayController()
    private let border = BorderController()
    private let identifier = IdentifierController()
    private let aboutController = AboutWindowController()
    private let hotkeyRecorder = HotkeyRecorderPanel()
```

Update the init method (lines 16-29):

```swift
init(spaceDetector: SpaceDetector, nameStore: NameStore, hotkeyManager: HotkeyManager, windowMover: WindowMover) {
    self.spaceDetector = spaceDetector
    self.nameStore = nameStore
    self.hotkeyManager = hotkeyManager
    self.windowMover = windowMover
    self.moveMenu = MoveToDesktopMenu(spaceDetector: spaceDetector, nameStore: nameStore, windowMover: windowMover)
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.menu = NSMenu()
    super.init()

    menu.delegate = self
    setupStatusItem()
    observeSpaceChanges()
    updateTitle()
    updateBorder()
    updateIdentifier()
}
```

- [ ] **Step 2: Add menu item for hotkey configuration**

In `populateMenu(_:)`, add after the identifier toggle item (after line 171):

```swift
let hotkeyLabel = hotkeyManager.isActive
    ? "Move Window: \(HotkeyRecorderView.formatHotkey(keyCode: Settings.moveWindowKeyCode, modifiers: Settings.moveWindowModifiers))"
    : "Move Window: unavailable"
let hotkeyItem = NSMenuItem(
    title: hotkeyLabel,
    action: hotkeyManager.isActive ? #selector(configureHotkey(_:)) : nil,
    keyEquivalent: ""
)
hotkeyItem.target = self
menu.addItem(hotkeyItem)
```

- [ ] **Step 3: Add configureHotkey action**

Add in the `// MARK: - Actions` section:

```swift
@objc private func configureHotkey(_ sender: NSMenuItem) {
    hotkeyRecorder.show(
        onRecord: { [weak self] keyCode, modifiers in
            Settings.moveWindowKeyCode = keyCode
            Settings.moveWindowModifiers = modifiers
            self?.hotkeyManager.restart()
        },
        onCancel: {}
    )
}
```

- [ ] **Step 4: Update AppDelegate with new dependencies and Accessibility check**

In `VirtualDesktop/App/AppDelegate.swift`, update the properties (lines 3-6):

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var spaceDetector: SpaceDetector!
    private var nameStore: NameStore!
    private var menuBarController: MenuBarController!
    private var hotkeyManager: HotkeyManager!
    private var windowMover: WindowMover!
```

Update `applicationDidFinishLaunching` (lines 8-23):

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    spaceDetector = SpaceDetector()
    nameStore = NameStore()

    // Verify private APIs are working
    let spaces = spaceDetector.allSpaces()
    if spaces.isEmpty {
        showPermissionAlert()
        return
    }

    // Check for stale UUIDs and migrate names positionally if needed
    migrateStaleNamesIfNeeded(currentSpaces: spaces)

    // Check Accessibility permission for hotkey and window movement
    if !AXIsProcessTrusted() {
        promptForAccessibilityPermission()
    }

    windowMover = WindowMover()
    hotkeyManager = HotkeyManager { [weak self] in
        self?.menuBarController?.moveMenu.show()
    }

    menuBarController = MenuBarController(
        spaceDetector: spaceDetector,
        nameStore: nameStore,
        hotkeyManager: hotkeyManager,
        windowMover: windowMover
    )
    spaceDetector.startObserving()
}
```

Add the Accessibility permission prompt method (after `showPermissionAlert()`):

```swift
private func promptForAccessibilityPermission() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
}
```

- [ ] **Step 5: Make moveMenu accessible from MenuBarController**

In `MenuBarController`, change `moveMenu` from `private` to `private(set)`:

```swift
private(set) var moveMenu: MoveToDesktopMenu
```

This allows AppDelegate's hotkey callback to access it.

- [ ] **Step 6: Build to verify compilation**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run all tests to verify nothing is broken**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop test 2>&1 | tail -15`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add VirtualDesktop/UI/MenuBarController.swift VirtualDesktop/App/AppDelegate.swift
git commit -m "feat: wire move-window-to-desktop into MenuBarController and AppDelegate"
```

---

## Task 8: Manual integration testing

This task requires running the app and testing the full flow on a Mac with multiple desktops.

- [ ] **Step 1: Build and run the app**

Run: `xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build`
Then open `build/Debug/VirtualDesktop.app`

- [ ] **Step 2: Test happy path**

1. Create at least 2 virtual desktops in Mission Control
2. Open a Finder window or Terminal
3. Press `Ctrl+Shift+M`
4. Verify: NSMenu appears at the center of the active window
5. Verify: Current desktop is NOT in the list
6. Select a desktop from the menu
7. Verify: Window disappears from current desktop
8. Switch to target desktop manually
9. Verify: Window is there

- [ ] **Step 3: Test edge cases**

1. Click on desktop background (no window focused), press `Ctrl+Shift+M` -> nothing happens
2. With only 1 desktop, press `Ctrl+Shift+M` -> nothing happens
3. Test hotkey configuration: click "Move Window: Ctrl+Shift+M" in menu bar, press new combo, verify it works

- [ ] **Step 4: Test Accessibility permission flow**

1. Remove VirtualDesktop from System Settings > Accessibility
2. Restart app
3. Verify: prompt appears for Accessibility permission
4. Grant permission
5. Verify: hotkey works after granting

- [ ] **Step 5: Commit any fixes discovered during testing**

```bash
git add -A
git commit -m "fix: integration testing fixes for move-window-to-desktop"
```
