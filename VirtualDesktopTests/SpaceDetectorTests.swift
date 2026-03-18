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
