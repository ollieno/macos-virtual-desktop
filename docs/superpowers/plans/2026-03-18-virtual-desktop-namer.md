# VirtualDesktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that lets users assign custom names to their virtual desktops (Spaces) and always displays the current desktop's name.

**Architecture:** AppKit menu bar app (LSUIElement) with SwiftUI views for the rename popover. Private APIs from SkyLight framework detect Spaces. UserDefaults persists names.

**Tech Stack:** Swift, AppKit, SwiftUI, SkyLight private APIs, SMAppService

**Spec:** `docs/superpowers/specs/2026-03-18-virtual-desktop-namer-design.md`

---

## File Structure

```
VirtualDesktop/
├── VirtualDesktop.xcodeproj/
├── VirtualDesktop/
│   ├── App/
│   │   └── AppDelegate.swift          # App entry point, wires components together
│   ├── Services/
│   │   ├── PrivateAPIs.swift          # SkyLight private API declarations via dlsym
│   │   ├── SpaceDetector.swift        # Detects current Space and tracks switches
│   │   └── NameStore.swift            # Maps Space IDs to user-defined names
│   ├── UI/
│   │   ├── MenuBarController.swift    # NSStatusItem and NSMenu management
│   │   └── RenamePopover.swift        # SwiftUI popover for renaming a desktop
│   ├── Info.plist
│   └── VirtualDesktop.entitlements
└── VirtualDesktopTests/
    ├── NameStoreTests.swift
    └── SpaceDetectorTests.swift
```

---

## Task 1: Create Xcode Project Skeleton

**Files:**
- Create: `VirtualDesktop.xcodeproj` (via Xcode CLI)
- Create: `VirtualDesktop/App/AppDelegate.swift`
- Create: `VirtualDesktop/Info.plist`

- [ ] **Step 1: Generate Xcode project**

Create a new macOS App project. We use Swift Package Manager with `swift package init` and then convert, but for a menu bar app it's simpler to create the project structure manually and use `xcodebuild`. However, the most reliable approach for a first-time macOS developer is to scaffold with a `Package.swift` that builds an executable.

Actually, for a menu bar app we need an `.app` bundle with `Info.plist`. The simplest approach: create the Xcode project using `xcodegen` or manually.

Create the project using a `project.yml` for XcodeGen:

```yaml
name: VirtualDesktop
options:
  bundleIdPrefix: com.jeroen
  deploymentTarget:
    macOS: "15.0"
  xcodeVersion: "16.0"
targets:
  VirtualDesktop:
    type: application
    platform: macOS
    sources:
      - VirtualDesktop
    settings:
      base:
        INFOPLIST_FILE: VirtualDesktop/Info.plist
        CODE_SIGN_ENTITLEMENTS: VirtualDesktop/VirtualDesktop.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.jeroen.VirtualDesktop
        MACOSX_DEPLOYMENT_TARGET: "15.0"
        SWIFT_VERSION: "5.10"
  VirtualDesktopTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - VirtualDesktopTests
    dependencies:
      - target: VirtualDesktop
    settings:
      base:
        BUNDLE_LOADER: $(TEST_HOST)
        TEST_HOST: $(BUILT_PRODUCTS_DIR)/VirtualDesktop.app/Contents/MacOS/VirtualDesktop
```

If `xcodegen` is not installed, install it first:
```bash
brew install xcodegen
```

- [ ] **Step 2: Create Info.plist**

Create `VirtualDesktop/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>VirtualDesktop</string>
    <key>CFBundleDisplayName</key>
    <string>VirtualDesktop</string>
    <key>CFBundleIdentifier</key>
    <string>com.jeroen.VirtualDesktop</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>VirtualDesktop</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Jeroen. All rights reserved.</string>
</dict>
</dict>
</plist>
```

Key: `LSUIElement = true` makes this a menu bar-only app (no Dock icon, no main window).

- [ ] **Step 3: Create entitlements file**

Create `VirtualDesktop/VirtualDesktop.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

Note: Sandbox must be disabled for private API access.

- [ ] **Step 4: Create minimal AppDelegate**

Create `VirtualDesktop/App/AppDelegate.swift`:

```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("VirtualDesktop launched")
    }
}
```

- [ ] **Step 5: Generate project and verify it builds**

```bash
cd /Users/jeroen/Development/MacOS/VirtualDesktop
xcodegen generate
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project for menu bar app"
```

---

## Task 2: Private API Bridge

**Files:**
- Create: `VirtualDesktop/Services/PrivateAPIs.swift`
- Test: `VirtualDesktopTests/SpaceDetectorTests.swift` (basic connectivity test)

- [ ] **Step 1: Write a test that verifies private APIs are loadable**

Create `VirtualDesktopTests/SpaceDetectorTests.swift`:

```swift
import XCTest
@testable import VirtualDesktop

final class PrivateAPITests: XCTestCase {
    func testSkyLightFrameworkLoads() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        XCTAssertNotNil(handle, "SkyLight framework should be loadable")
        if let handle { dlclose(handle) }
    }

    func testCGSGetActiveSpaceIsAvailable() {
        let space = PrivateAPIs.getActiveSpaceID()
        XCTAssertGreaterThan(space, 0, "Active space ID should be a positive number")
    }

    func testCGSCopyManagedDisplaySpacesReturnsData() {
        let spaces = PrivateAPIs.getManagedDisplaySpaces()
        XCTAssertFalse(spaces.isEmpty, "Should return at least one display with spaces")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: FAIL (PrivateAPIs type does not exist)

- [ ] **Step 3: Implement PrivateAPIs**

Create `VirtualDesktop/Services/PrivateAPIs.swift`:

```swift
import Foundation

/// Bridge to macOS private APIs in SkyLight framework for Space detection.
/// These APIs are undocumented but widely used by tools like yabai and Amethyst.
enum PrivateAPIs {

    // MARK: - Types

    private typealias CGSConnectionID = UInt32
    private typealias CGSSpaceID = UInt64

    // MARK: - Function pointers (loaded via dlsym)

    private static let skyLightHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    }()

    private static let _CGSMainConnectionID: (@convention(c) () -> CGSConnectionID)? = {
        guard let handle = skyLightHandle,
              let sym = dlsym(handle, "CGSMainConnectionID") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) () -> CGSConnectionID).self)
    }()

    private static let _CGSGetActiveSpace: (@convention(c) (CGSConnectionID) -> CGSSpaceID)? = {
        guard let handle = skyLightHandle,
              let sym = dlsym(handle, "CGSGetActiveSpace") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGSConnectionID) -> CGSSpaceID).self)
    }()

    private static let _CGSCopyManagedDisplaySpaces: (@convention(c) (CGSConnectionID) -> CFArray?)? = {
        guard let handle = skyLightHandle,
              let sym = dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGSConnectionID) -> CFArray?).self)
    }()

    // MARK: - Public interface

    /// Returns the Space ID of the currently active Space, or 0 if unavailable.
    static func getActiveSpaceID() -> UInt64 {
        guard let mainConn = _CGSMainConnectionID,
              let getActive = _CGSGetActiveSpace else { return 0 }
        return getActive(mainConn())
    }

    /// Returns the raw display-spaces data from CGSCopyManagedDisplaySpaces.
    /// Each element is a dictionary with a "Spaces" key containing an array of Space dictionaries.
    static func getManagedDisplaySpaces() -> [[String: Any]] {
        guard let mainConn = _CGSMainConnectionID,
              let copySpaces = _CGSCopyManagedDisplaySpaces else { return [] }
        let conn = mainConn()
        guard let cfArray = copySpaces(conn) else { return [] }
        let array = cfArray as [AnyObject]
        return array.compactMap { $0 as? [String: Any] }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: All 3 tests PASS. Note: these tests require Screen Recording permission for the test runner.

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/PrivateAPIs.swift VirtualDesktopTests/SpaceDetectorTests.swift
git commit -m "feat: add SkyLight private API bridge via dlsym"
```

---

## Task 3: NameStore

**Files:**
- Create: `VirtualDesktop/Services/NameStore.swift`
- Create: `VirtualDesktopTests/NameStoreTests.swift`

- [ ] **Step 1: Write failing tests for NameStore**

Create `VirtualDesktopTests/NameStoreTests.swift`:

```swift
import XCTest
@testable import VirtualDesktop

final class NameStoreTests: XCTestCase {
    private var store: NameStore!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use a separate suite so tests don't affect real data
        defaults = UserDefaults(suiteName: "com.jeroen.VirtualDesktop.tests")!
        defaults.removePersistentDomain(forName: "com.jeroen.VirtualDesktop.tests")
        store = NameStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "com.jeroen.VirtualDesktop.tests")
        super.tearDown()
    }

    func testDefaultNameForUnknownSpace() {
        let name = store.name(forSpaceID: "unknown-uuid", atIndex: 2)
        XCTAssertEqual(name, "Desktop 3") // 0-indexed, display as 1-indexed
    }

    func testSetAndGetName() {
        store.setName("Code", forSpaceID: "uuid-123")
        let name = store.name(forSpaceID: "uuid-123", atIndex: 0)
        XCTAssertEqual(name, "Code")
    }

    func testNamePersistsAcrossInstances() {
        store.setName("Email", forSpaceID: "uuid-456")
        let newStore = NameStore(defaults: defaults)
        let name = newStore.name(forSpaceID: "uuid-456", atIndex: 0)
        XCTAssertEqual(name, "Email")
    }

    func testTruncatesLongNames() {
        let longName = "This Is A Very Long Desktop Name That Exceeds Twenty Characters"
        store.setName(longName, forSpaceID: "uuid-789")
        let displayName = store.displayName(forSpaceID: "uuid-789", atIndex: 0)
        XCTAssertEqual(displayName.count, 20)
        XCTAssertTrue(displayName.hasSuffix("…"))
    }

    func testFullNameNotTruncated() {
        let longName = "This Is A Very Long Desktop Name"
        store.setName(longName, forSpaceID: "uuid-789")
        let fullName = store.name(forSpaceID: "uuid-789", atIndex: 0)
        XCTAssertEqual(fullName, longName)
    }

    func testShortNameNotTruncated() {
        store.setName("Code", forSpaceID: "uuid-abc")
        let displayName = store.displayName(forSpaceID: "uuid-abc", atIndex: 0)
        XCTAssertEqual(displayName, "Code")
    }

    func testAllNames() {
        store.setName("Code", forSpaceID: "uuid-1")
        store.setName("Email", forSpaceID: "uuid-2")
        let all = store.allNames()
        XCTAssertEqual(all["uuid-1"], "Code")
        XCTAssertEqual(all["uuid-2"], "Email")
    }

    func testRemoveName() {
        store.setName("Code", forSpaceID: "uuid-1")
        store.removeName(forSpaceID: "uuid-1")
        let name = store.name(forSpaceID: "uuid-1", atIndex: 0)
        XCTAssertEqual(name, "Desktop 1")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: FAIL (NameStore type does not exist)

- [ ] **Step 3: Implement NameStore**

Create `VirtualDesktop/Services/NameStore.swift`:

```swift
import Foundation

final class NameStore {
    private static let storageKey = "desktop_names"
    private static let maxDisplayLength = 20

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the full (non-truncated) custom name for a Space, or "Desktop N" as fallback.
    func name(forSpaceID spaceID: String, atIndex index: Int) -> String {
        let names = allNames()
        return names[spaceID] ?? "Desktop \(index + 1)"
    }

    /// Returns the display name (truncated to max 20 chars) for use in the menu bar.
    func displayName(forSpaceID spaceID: String, atIndex index: Int) -> String {
        let full = name(forSpaceID: spaceID, atIndex: index)
        return Self.truncate(full)
    }

    func setName(_ name: String, forSpaceID spaceID: String) {
        var names = allNames()
        names[spaceID] = name
        save(names)
    }

    func removeName(forSpaceID spaceID: String) {
        var names = allNames()
        names.removeValue(forKey: spaceID)
        save(names)
    }

    func allNames() -> [String: String] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
    }

    // MARK: - Private

    private func save(_ names: [String: String]) {
        defaults.set(names, forKey: Self.storageKey)
    }

    private static func truncate(_ text: String) -> String {
        guard text.count > maxDisplayLength else { return text }
        let truncated = text.prefix(maxDisplayLength - 1)
        return truncated + "…"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: All 8 NameStore tests PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/NameStore.swift VirtualDesktopTests/NameStoreTests.swift
git commit -m "feat: add NameStore with UserDefaults persistence and truncation"
```

---

## Task 4: SpaceDetector

**Files:**
- Create: `VirtualDesktop/Services/SpaceDetector.swift`
- Modify: `VirtualDesktopTests/SpaceDetectorTests.swift`

- [ ] **Step 1: Write failing tests for SpaceDetector**

Add to `VirtualDesktopTests/SpaceDetectorTests.swift` (keep existing PrivateAPI tests, add new class):

```swift
final class SpaceDetectorTests: XCTestCase {
    func testDetectsAtLeastOneSpace() {
        let detector = SpaceDetector()
        let spaces = detector.allSpaces()
        XCTAssertFalse(spaces.isEmpty, "Should detect at least one Space")
    }

    func testActiveSpaceIsInList() {
        let detector = SpaceDetector()
        let spaces = detector.allSpaces()
        let active = detector.activeSpaceID()
        XCTAssertTrue(
            spaces.contains(where: { $0.id == active }),
            "Active space should be in the list of all spaces"
        )
    }

    func testSpacesHaveSequentialIndices() {
        let detector = SpaceDetector()
        let spaces = detector.allSpaces()
        for (i, space) in spaces.enumerated() {
            XCTAssertEqual(space.index, i, "Space index should match position")
        }
    }

    func testActiveSpaceIndex() {
        let detector = SpaceDetector()
        let index = detector.activeSpaceIndex()
        XCTAssertGreaterThanOrEqual(index, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: FAIL (SpaceDetector type does not exist)

- [ ] **Step 3: Implement SpaceDetector**

Create `VirtualDesktop/Services/SpaceDetector.swift`:

```swift
import Cocoa

struct SpaceInfo {
    let id: UInt64
    let uuid: String
    let index: Int
}

/// Detects macOS Spaces (virtual desktops) and tracks the active Space.
/// Posts a notification when the active Space changes.
final class SpaceDetector {
    static let activeSpaceDidChange = Notification.Name("SpaceDetector.activeSpaceDidChange")

    private var observation: NSObjectProtocol?

    init() {}

    /// Start listening for Space change notifications.
    func startObserving() {
        observation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }
    }

    /// Stop listening for Space change notifications.
    func stopObserving() {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
        observation = nil
    }

    /// Returns the Space ID of the currently active Space.
    func activeSpaceID() -> UInt64 {
        PrivateAPIs.getActiveSpaceID()
    }

    /// Returns the index (0-based) of the currently active Space in the list.
    func activeSpaceIndex() -> Int {
        let active = activeSpaceID()
        let spaces = allSpaces()
        return spaces.firstIndex(where: { $0.id == active }) ?? 0
    }

    /// Returns all Spaces in order, with their IDs, UUIDs, and indices.
    func allSpaces() -> [SpaceInfo] {
        let displays = PrivateAPIs.getManagedDisplaySpaces()
        var result: [SpaceInfo] = []
        var index = 0

        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                // Space type 0 = user-created desktop, type 4 = fullscreen app
                let type = space["type"] as? Int ?? 0
                guard type == 0 else { continue }

                let id = space["id64"] as? UInt64 ?? 0
                let uuid = space["uuid"] as? String ?? ""

                result.append(SpaceInfo(id: id, uuid: uuid, index: index))
                index += 1
            }
        }

        return result
    }

    /// Returns the UUID of the currently active Space.
    func activeSpaceUUID() -> String {
        let active = activeSpaceID()
        let spaces = allSpaces()
        return spaces.first(where: { $0.id == active })?.uuid ?? ""
    }

    // MARK: - Private

    private func handleSpaceChange() {
        NotificationCenter.default.post(name: Self.activeSpaceDidChange, object: self)
    }

    deinit {
        stopObserving()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: All SpaceDetector and PrivateAPI tests PASS

- [ ] **Step 5: Commit**

```bash
git add VirtualDesktop/Services/SpaceDetector.swift VirtualDesktopTests/SpaceDetectorTests.swift
git commit -m "feat: add SpaceDetector with Space enumeration and change tracking"
```

---

## Task 5: Rename Popover (SwiftUI)

**Files:**
- Create: `VirtualDesktop/UI/RenamePopover.swift`

- [ ] **Step 1: Create the SwiftUI rename view**

Create `VirtualDesktop/UI/RenamePopover.swift`:

```swift
import SwiftUI

struct RenamePopoverView: View {
    let currentName: String
    let onRename: (String) -> Void
    let onCancel: () -> Void

    @State private var newName: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Rename Desktop")
                .font(.headline)

            TextField("Desktop name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit {
                    submitName()
                }

            HStack(spacing: 8) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    submitName()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .onAppear {
            newName = currentName
        }
    }

    private func submitName() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onRename(trimmed)
    }
}

/// Wraps the SwiftUI view in an NSPopover for use from AppKit.
final class RenamePopover: NSPopover {
    private let spaceUUID: String
    private let currentName: String
    private let onRename: (String, String) -> Void // (spaceUUID, newName)

    init(spaceUUID: String, currentName: String, onRename: @escaping (String, String) -> Void) {
        self.spaceUUID = spaceUUID
        self.currentName = currentName
        self.onRename = onRename
        super.init()

        self.behavior = .transient
        self.contentSize = NSSize(width: 250, height: 120)

        let view = RenamePopoverView(
            currentName: currentName,
            onRename: { [weak self] newName in
                guard let self else { return }
                self.onRename(self.spaceUUID, newName)
                self.performClose(nil)
            },
            onCancel: { [weak self] in
                self?.performClose(nil)
            }
        )
        self.contentViewController = NSHostingController(rootView: view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add VirtualDesktop/UI/RenamePopover.swift
git commit -m "feat: add SwiftUI rename popover for desktop naming"
```

---

## Task 6: MenuBarController

**Files:**
- Create: `VirtualDesktop/UI/MenuBarController.swift`

- [ ] **Step 1: Implement MenuBarController**

Create `VirtualDesktop/UI/MenuBarController.swift`:

```swift
import Cocoa

/// Manages the NSStatusItem (menu bar icon) and dropdown menu.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let spaceDetector: SpaceDetector
    private let nameStore: NameStore
    private var spaceChangeObservation: NSObjectProtocol?

    init(spaceDetector: SpaceDetector, nameStore: NameStore) {
        self.spaceDetector = spaceDetector
        self.nameStore = nameStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusItem()
        observeSpaceChanges()
        updateTitle()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeSpaceChanges() {
        spaceChangeObservation = NotificationCenter.default.addObserver(
            forName: SpaceDetector.activeSpaceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTitle()
        }
    }

    // MARK: - Update

    func updateTitle() {
        let uuid = spaceDetector.activeSpaceUUID()
        let index = spaceDetector.activeSpaceIndex()
        let displayName = nameStore.displayName(forSpaceID: uuid, atIndex: index)
        statusItem.button?.title = displayName
    }

    // MARK: - Menu

    @objc private func statusItemClicked() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Reset menu so next click triggers action again
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let spaces = spaceDetector.allSpaces()
        let activeID = spaceDetector.activeSpaceID()

        for space in spaces {
            let name = nameStore.name(forSpaceID: space.uuid, atIndex: space.index)
            let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
            item.representedObject = space.uuid

            if space.id == activeID {
                item.state = .on // checkmark
            }

            // Add "Rename..." submenu action
            let renameItem = NSMenuItem(
                title: "Rename...",
                action: #selector(renameClicked(_:)),
                keyEquivalent: ""
            )
            renameItem.target = self
            renameItem.representedObject = space

            let submenu = NSMenu()
            submenu.addItem(renameItem)
            item.submenu = submenu

            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit VirtualDesktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func renameClicked(_ sender: NSMenuItem) {
        guard let space = sender.representedObject as? SpaceInfo else { return }
        let currentName = nameStore.name(forSpaceID: space.uuid, atIndex: space.index)

        let popover = RenamePopover(
            spaceUUID: space.uuid,
            currentName: currentName,
            onRename: { [weak self] uuid, newName in
                self?.nameStore.setName(newName, forSpaceID: uuid)
                self?.updateTitle()
            }
        )

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    deinit {
        if let observation = spaceChangeObservation {
            NotificationCenter.default.removeObserver(observation)
        }
    }
}
```

Note: `LaunchAtLogin` is referenced here but implemented in Task 7.

- [ ] **Step 2: Build to verify compilation (will fail until Task 7)**

This step can be verified after Task 7. For now, proceed.

- [ ] **Step 3: Commit**

```bash
git add VirtualDesktop/UI/MenuBarController.swift
git commit -m "feat: add MenuBarController with dropdown and rename popover"
```

---

## Task 7: Launch at Login

**Files:**
- Create: `VirtualDesktop/Services/LaunchAtLogin.swift`

- [ ] **Step 1: Implement LaunchAtLogin helper**

Create `VirtualDesktop/Services/LaunchAtLogin.swift`:

```swift
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func enable() {
        try? SMAppService.mainApp.register()
    }

    static func disable() {
        try? SMAppService.mainApp.unregister()
    }

    static func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add VirtualDesktop/Services/LaunchAtLogin.swift
git commit -m "feat: add launch-at-login via SMAppService"
```

---

## Task 8: Wire Everything Together in AppDelegate

**Files:**
- Modify: `VirtualDesktop/App/AppDelegate.swift`

- [ ] **Step 1: Update AppDelegate to wire all components**

Replace contents of `VirtualDesktop/App/AppDelegate.swift`:

```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var spaceDetector: SpaceDetector!
    private var nameStore: NameStore!
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        spaceDetector = SpaceDetector()
        nameStore = NameStore()
        menuBarController = MenuBarController(spaceDetector: spaceDetector, nameStore: nameStore)

        spaceDetector.startObserving()

        // Verify private APIs are working
        let spaces = spaceDetector.allSpaces()
        if spaces.isEmpty {
            showPermissionAlert()
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "VirtualDesktop needs Screen Recording permission"
        alert.informativeText = "To detect your virtual desktops, VirtualDesktop needs Screen Recording permission. Please grant this in System Settings > Privacy & Security > Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
}
```

- [ ] **Step 2: Build and run manually**

```bash
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build
```

Expected: BUILD SUCCEEDED

Then run the app manually to verify:
```bash
open /Users/jeroen/Development/MacOS/VirtualDesktop/build/Debug/VirtualDesktop.app
```

Manual verification checklist:
- Menu bar shows "Desktop 1" (or similar default name)
- Clicking shows dropdown with all desktops
- Active desktop has a checkmark
- "Rename..." opens popover
- Typing a new name and pressing Save updates the menu bar
- Switching desktops (Ctrl+Arrow) updates the name

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -project VirtualDesktop.xcodeproj -scheme VirtualDesktopTests -configuration Debug
```

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add VirtualDesktop/App/AppDelegate.swift
git commit -m "feat: wire all components together in AppDelegate"
```

---

## Task 9: Final Polish and .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Add .gitignore**

Create `.gitignore`:

```gitignore
# Xcode
build/
DerivedData/
*.xcuserstate
xcuserdata/

# macOS
.DS_Store

# Swift Package Manager
.build/
.swiftpm/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for Xcode and macOS artifacts"
```

- [ ] **Step 3: Full end-to-end manual test**

Build and run:
```bash
xcodebuild -project VirtualDesktop.xcodeproj -scheme VirtualDesktop -configuration Debug build
open build/Debug/VirtualDesktop.app
```

Verify all success criteria from spec:
- [ ] App shows desktop name in menu bar at all times
- [ ] Switching desktops updates the name within 1 second
- [ ] Names persist after quitting and relaunching
- [ ] Can rename any desktop via the popover
- [ ] Launch at Login toggle works
