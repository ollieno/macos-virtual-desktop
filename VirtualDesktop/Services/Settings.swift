import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    static var showBorder: Bool {
        get { defaults.object(forKey: "showBorder") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showBorder") }
    }

    static func toggleBorder() {
        showBorder = !showBorder
    }

    static var showIdentifier: Bool {
        get { defaults.object(forKey: "showIdentifier") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showIdentifier") }
    }

    static func toggleIdentifier() {
        showIdentifier = !showIdentifier
    }
}
