import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var spaceDetector: SpaceDetector!
    private var nameStore: NameStore!
    private var menuBarController: MenuBarController!

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

        menuBarController = MenuBarController(spaceDetector: spaceDetector, nameStore: nameStore)
        spaceDetector.startObserving()
    }

    private func migrateStaleNamesIfNeeded(currentSpaces: [SpaceInfo]) {
        let storedNames = nameStore.allNames()
        guard !storedNames.isEmpty else { return }

        let currentUUIDs = Set(currentSpaces.map(\.uuid))
        let staleUUIDs = storedNames.keys.filter { !currentUUIDs.contains($0) }
        guard !staleUUIDs.isEmpty else { return }

        let newUUIDs = currentSpaces.map(\.uuid)

        let alert = NSAlert()
        alert.messageText = "Desktop names need updating"
        alert.informativeText = "Your desktop UUIDs have changed (possibly after adding/removing desktops). VirtualDesktop can try to reassign your names based on desktop position. Migrate names?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Migrate")
        alert.addButton(withTitle: "Reset Names")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            nameStore.migrateNames(from: staleUUIDs.sorted(), to: newUUIDs)
        } else {
            for uuid in staleUUIDs {
                nameStore.removeName(forSpaceID: uuid)
            }
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
