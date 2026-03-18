import XCTest
@testable import VirtualDesktop

final class SettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "showIdentifier")
    }

    func testShowIdentifierDefaultsToTrue() {
        XCTAssertTrue(Settings.showIdentifier)
    }

    func testToggleIdentifier() {
        Settings.toggleIdentifier()
        XCTAssertFalse(Settings.showIdentifier)
        Settings.toggleIdentifier()
        XCTAssertTrue(Settings.showIdentifier)
    }
}
