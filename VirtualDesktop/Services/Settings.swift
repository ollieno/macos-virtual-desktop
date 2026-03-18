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
}
