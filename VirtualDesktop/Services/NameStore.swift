import Foundation

final class NameStore {
    private static let storageKey = "desktop_names"
    private static let maxDisplayLength = 20

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func name(forSpaceID spaceID: String, atIndex index: Int) -> String {
        let names = allNames()
        return names[spaceID] ?? "Desktop \(index + 1)"
    }

    /// Formatted for the menu bar: "1:Code" or "3:Desktop 3"
    func displayName(forSpaceID spaceID: String, atIndex index: Int) -> String {
        let full = name(forSpaceID: spaceID, atIndex: index)
        let numbered = "\(index + 1):\(full)"
        return Self.truncate(numbered)
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

    func resetAllNames() {
        save([:])
    }

    @discardableResult
    func migrateNames(from oldUUIDs: [String], to newUUIDs: [String]) -> [(name: String, newUUID: String)] {
        let names = allNames()
        var migrated: [(name: String, newUUID: String)] = []

        for (i, oldUUID) in oldUUIDs.enumerated() {
            guard i < newUUIDs.count,
                  let name = names[oldUUID] else { continue }
            let newUUID = newUUIDs[i]
            setName(name, forSpaceID: newUUID)
            removeName(forSpaceID: oldUUID)
            migrated.append((name: name, newUUID: newUUID))
        }

        return migrated
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
