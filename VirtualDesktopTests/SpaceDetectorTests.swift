import XCTest
@testable import VirtualDesktop

final class PrivateAPITests: XCTestCase {
    func testSkyLightFrameworkLoads() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        XCTAssertNotNil(handle, "SkyLight framework should be loadable")
        if let handle { dlclose(handle) }
    }

    func testCGSGetActiveSpaceIsAvailable() {
        let space = PrivateAPIs.getActiveSpaceID()
        XCTAssertGreaterThan(space, 0, "Active space ID should be a positive number")
    }

    func testCGSCopyManagedDisplaySpacesReturnsData() {
        let spaces = PrivateAPIs.getManagedDisplaySpaces()
        XCTAssertFalse(spaces.isEmpty, "Should return at least one display with spaces")
    }
}

final class SpaceDetectorTests: XCTestCase {
    func testDetectsAtLeastOneSpace() {
        let detector = SpaceDetector()
        let spaces = detector.allSpaces()
        XCTAssertFalse(spaces.isEmpty, "Should detect at least one Space")
    }

    func testActiveSpaceIsInList() {
        let detector = SpaceDetector()
        let spaces = detector.allSpaces()
        let active = detector.activeSpaceID()
        XCTAssertTrue(
            spaces.contains(where: { $0.id == active }),
            "Active space should be in the list of all spaces"
        )
    }

    func testSpacesHaveSequentialIndices() {
        let detector = SpaceDetector()
        let spaces = detector.allSpaces()
        for (i, space) in spaces.enumerated() {
            XCTAssertEqual(space.index, i, "Space index should match position")
        }
    }

    func testActiveSpaceIndex() {
        let detector = SpaceDetector()
        let index = detector.activeSpaceIndex()
        XCTAssertGreaterThanOrEqual(index, 0)
    }
}
