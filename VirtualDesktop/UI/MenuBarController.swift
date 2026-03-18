import Cocoa

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let spaceDetector: SpaceDetector
    private let nameStore: NameStore
    private var spaceChangeObservation: NSObjectProtocol?
    private var activePopover: RenamePopover?

    init(spaceDetector: SpaceDetector, nameStore: NameStore) {
        self.spaceDetector = spaceDetector
        self.nameStore = nameStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        setupStatusItem()
        observeSpaceChanges()
        updateTitle()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        populateMenu(menu)
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

    // MARK: - Menu Building

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let spaces = spaceDetector.allSpaces()
        let activeID = spaceDetector.activeSpaceID()

        for space in spaces {
            let name = nameStore.name(forSpaceID: space.uuid, atIndex: space.index)
            let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")

            if space.id == activeID {
                item.state = .on
            }

            let renameItem = NSMenuItem(
                title: "Rename...",
                action: #selector(renameClicked(_:)),
                keyEquivalent: ""
            )
            renameItem.target = self
            renameItem.representedObject = ["uuid": space.uuid, "index": space.index] as [String: Any]

            let submenu = NSMenu()
            submenu.addItem(renameItem)
            item.submenu = submenu

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

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        populateMenu(menu)
    }

    // MARK: - Actions

    @objc private func renameClicked(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let uuid = info["uuid"] as? String,
              let index = info["index"] as? Int else { return }
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
        if let observation = spaceChangeObservation {
            NotificationCenter.default.removeObserver(observation)
        }
    }
}
