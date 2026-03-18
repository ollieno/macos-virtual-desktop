import XCTest
@testable import VirtualDesktop

final class NameStoreTests: XCTestCase {
    private var store: NameStore!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
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
        XCTAssertEqual(name, "Desktop 3")
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
        // Format: "1:This Is A Very Lo…" (20 chars total including prefix)
        XCTAssertEqual(displayName.count, 20)
        XCTAssertTrue(displayName.hasPrefix("1:"))
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
        XCTAssertEqual(displayName, "1:Code")
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

    func testMigrateNamesPositionally() {
        store.setName("Code", forSpaceID: "old-uuid-1")
        store.setName("Email", forSpaceID: "old-uuid-2")
        store.setName("Design", forSpaceID: "old-uuid-3")

        let oldUUIDs = ["old-uuid-1", "old-uuid-2", "old-uuid-3"]
        let newUUIDs = ["new-uuid-1", "new-uuid-2", "new-uuid-3"]

        let migrated = store.migrateNames(from: oldUUIDs, to: newUUIDs)
        XCTAssertEqual(migrated.count, 3)
        XCTAssertEqual(store.name(forSpaceID: "new-uuid-1", atIndex: 0), "Code")
        XCTAssertEqual(store.name(forSpaceID: "new-uuid-2", atIndex: 1), "Email")
        XCTAssertEqual(store.name(forSpaceID: "new-uuid-3", atIndex: 2), "Design")
    }

    func testMigrateSkipsUnnamedSpaces() {
        store.setName("Code", forSpaceID: "old-uuid-1")

        let oldUUIDs = ["old-uuid-1", "old-uuid-2"]
        let newUUIDs = ["new-uuid-1", "new-uuid-2"]

        let migrated = store.migrateNames(from: oldUUIDs, to: newUUIDs)
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(store.name(forSpaceID: "new-uuid-1", atIndex: 0), "Code")
        XCTAssertEqual(store.name(forSpaceID: "new-uuid-2", atIndex: 1), "Desktop 2")
    }
}
