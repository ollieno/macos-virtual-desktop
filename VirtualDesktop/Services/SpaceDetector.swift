import Cocoa

struct SpaceInfo {
    let id: UInt64
    let uuid: String
    let index: Int
}

final class SpaceDetector {
    static let activeSpaceDidChange = Notification.Name("SpaceDetector.activeSpaceDidChange")

    private var observation: NSObjectProtocol?

    init() {}

    func startObserving() {
        observation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }
    }

    func stopObserving() {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
        observation = nil
    }

    func activeSpaceID() -> UInt64 {
        PrivateAPIs.getActiveSpaceID()
    }

    func activeSpaceIndex() -> Int {
        let active = activeSpaceID()
        let spaces = allSpaces()
        return spaces.firstIndex(where: { $0.id == active }) ?? 0
    }

    func allSpaces() -> [SpaceInfo] {
        let displays = PrivateAPIs.getManagedDisplaySpaces()
        var result: [SpaceInfo] = []
        var index = 0

        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
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
