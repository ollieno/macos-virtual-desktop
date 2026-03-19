import Cocoa

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let spaceDetector: SpaceDetector
    private let nameStore: NameStore
    private var spaceChangeObservation: NSObjectProtocol?
    private var activePopover: RenamePopover?
    private var clickTimer: Timer?
    private let menu: NSMenu
    private let overlay = OverlayController()
    private let border = BorderController()
    private let identifier = IdentifierController()
    private let aboutController = AboutWindowController()

    init(spaceDetector: SpaceDetector, nameStore: NameStore) {
        self.spaceDetector = spaceDetector
        self.nameStore = nameStore
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

    // MARK: - Setup

    private func setupStatusItem() {
        // Don't assign menu directly: we handle clicks ourselves
        // to distinguish single-click (open menu) from double-click (rename)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp])
    }

    private func observeSpaceChanges() {
        spaceChangeObservation = NotificationCenter.default.addObserver(
            forName: SpaceDetector.activeSpaceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.updateTitle()
            let uuid = self.spaceDetector.activeSpaceUUID()
            let index = self.spaceDetector.activeSpaceIndex()
            let name = self.nameStore.displayName(forSpaceID: uuid, atIndex: index)
            self.overlay.show(name: name, desktopIndex: index)
            self.updateBorder()
            self.updateIdentifier()
        }
    }

    // MARK: - Click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let clickCount = event?.clickCount ?? 1

        if clickCount == 2 {
            // Double-click: cancel pending single-click and rename current desktop
            clickTimer?.invalidate()
            clickTimer = nil
            renameCurrentDesktop()
        } else {
            // Single click: wait briefly to see if a double-click follows
            clickTimer?.invalidate()
            clickTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.doubleClickInterval, repeats: false) { [weak self] _ in
                self?.showMenu()
            }
        }
    }

    private func showMenu() {
        populateMenu(menu)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Remove menu immediately so future clicks go to our action handler again
        statusItem.menu = nil
    }

    // MARK: - Update

    private func updateBorder() {
        let index = spaceDetector.activeSpaceIndex()
        if Settings.showBorder {
            border.update(index: index)
        } else {
            border.hide()
        }
    }

    private func updateIdentifier() {
        let uuid = spaceDetector.activeSpaceUUID()
        let index = spaceDetector.activeSpaceIndex()
        if Settings.showIdentifier {
            let name = nameStore.displayName(forSpaceID: uuid, atIndex: index)
            identifier.update(name: name, index: index, spaceUUID: uuid)
        } else {
            identifier.hide()
        }
    }

    func updateTitle() {
        let uuid = spaceDetector.activeSpaceUUID()
        let index = spaceDetector.activeSpaceIndex()
        let displayName = nameStore.displayName(forSpaceID: uuid, atIndex: index)
        statusItem.button?.title = displayName
    }

    // MARK: - Menu Building

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let aboutItem = NSMenuItem(
            title: "About VirtualDesktop",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        let spaces = spaceDetector.allSpaces()
        let activeID = spaceDetector.activeSpaceID()

        for space in spaces {
            let name = nameStore.name(forSpaceID: space.uuid, atIndex: space.index)
            let title = "\(space.index + 1):\(name)"
            let item = NSMenuItem(title: title, action: #selector(renameClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["uuid": space.uuid, "index": space.index] as [String: Any]

            if space.id == activeID {
                item.state = .on
            }

            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        let borderItem = NSMenuItem(
            title: "Show Border Colors",
            action: #selector(toggleBorderColors(_:)),
            keyEquivalent: ""
        )
        borderItem.target = self
        borderItem.state = Settings.showBorder ? .on : .off
        menu.addItem(borderItem)

        let identifierItem = NSMenuItem(
            title: "Show Desktop Identifier",
            action: #selector(toggleIdentifier(_:)),
            keyEquivalent: ""
        )
        identifierItem.target = self
        identifierItem.state = Settings.showIdentifier ? .on : .off
        menu.addItem(identifierItem)

        let resetItem = NSMenuItem(
            title: "Reset Desktop Names",
            action: #selector(resetDesktopNames(_:)),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit VirtualDesktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func showAbout(_ sender: NSMenuItem) {
        aboutController.showAbout()
    }

    private func renameCurrentDesktop() {
        let uuid = spaceDetector.activeSpaceUUID()
        let index = spaceDetector.activeSpaceIndex()
        showRenamePopover(forUUID: uuid, atIndex: index)
    }

    @objc private func renameClicked(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let uuid = info["uuid"] as? String,
              let index = info["index"] as? Int else { return }
        showRenamePopover(forUUID: uuid, atIndex: index)
    }

    private func showRenamePopover(forUUID uuid: String, atIndex index: Int) {
        let currentName = nameStore.name(forSpaceID: uuid, atIndex: index)

        let popover = RenamePopover(
            spaceUUID: uuid,
            currentName: currentName,
            onRename: { [weak self] uuid, newName in
                self?.nameStore.setName(newName, forSpaceID: uuid)
                self?.updateTitle()
                self?.updateIdentifier()
            }
        )

        activePopover = popover

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func resetDesktopNames(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Reset Desktop Names"
        alert.informativeText = "All desktops will be renamed back to their default names (Desktop 1, Desktop 2, etc.)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        nameStore.resetAllNames()
        updateTitle()
        updateIdentifier()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func toggleBorderColors(_ sender: NSMenuItem) {
        Settings.toggleBorder()
        sender.state = Settings.showBorder ? .on : .off
        updateBorder()
    }

    @objc private func toggleIdentifier(_ sender: NSMenuItem) {
        Settings.toggleIdentifier()
        sender.state = Settings.showIdentifier ? .on : .off
        updateIdentifier()
    }

    deinit {
        clickTimer?.invalidate()
        if let observation = spaceChangeObservation {
            NotificationCenter.default.removeObserver(observation)
        }
    }
}
