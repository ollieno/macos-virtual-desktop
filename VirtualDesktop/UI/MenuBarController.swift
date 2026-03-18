import Cocoa

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let spaceDetector: SpaceDetector
    private let nameStore: NameStore
    private var spaceChangeObservation: NSObjectProtocol?
    private var activePopover: RenamePopover?
    private var clickTimer: Timer?
    private let menu: NSMenu
    private let overlay = OverlayWindow()

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
            self.overlay.show(name: name)
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

    func updateTitle() {
        let uuid = spaceDetector.activeSpaceUUID()
        let index = spaceDetector.activeSpaceIndex()
        let displayName = nameStore.displayName(forSpaceID: uuid, atIndex: index)
        statusItem.button?.title = displayName
    }

    // MARK: - Menu Building

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
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

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit VirtualDesktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Actions

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
            }
        )

        activePopover = popover

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    deinit {
        clickTimer?.invalidate()
        if let observation = spaceChangeObservation {
            NotificationCenter.default.removeObserver(observation)
        }
    }
}
