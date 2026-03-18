import Foundation

/// Bridge to macOS private APIs in SkyLight framework for Space detection.
/// These APIs are undocumented but widely used by tools like yabai and Amethyst.
enum PrivateAPIs {

    // MARK: - Types

    private typealias CGSConnectionID = UInt32
    private typealias CGSSpaceID = UInt64

    // MARK: - Function pointers (loaded via dlsym)

    private static let skyLightHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    }()

    private static let _CGSMainConnectionID: (@convention(c) () -> CGSConnectionID)? = {
        guard let handle = skyLightHandle,
              let sym = dlsym(handle, "CGSMainConnectionID") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) () -> CGSConnectionID).self)
    }()

    private static let _CGSGetActiveSpace: (@convention(c) (CGSConnectionID) -> CGSSpaceID)? = {
        guard let handle = skyLightHandle,
              let sym = dlsym(handle, "CGSGetActiveSpace") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGSConnectionID) -> CGSSpaceID).self)
    }()

    private static let _CGSCopyManagedDisplaySpaces: (@convention(c) (CGSConnectionID) -> CFArray?)? = {
        guard let handle = skyLightHandle,
              let sym = dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGSConnectionID) -> CFArray?).self)
    }()

    // MARK: - Public interface

    /// Returns the Space ID of the currently active Space, or 0 if unavailable.
    static func getActiveSpaceID() -> UInt64 {
        guard let mainConn = _CGSMainConnectionID,
              let getActive = _CGSGetActiveSpace else { return 0 }
        return getActive(mainConn())
    }

    /// Returns the raw display-spaces data from CGSCopyManagedDisplaySpaces.
    /// Each element is a dictionary with a "Spaces" key containing an array of Space dictionaries.
    static func getManagedDisplaySpaces() -> [[String: Any]] {
        guard let mainConn = _CGSMainConnectionID,
              let copySpaces = _CGSCopyManagedDisplaySpaces else { return [] }
        let conn = mainConn()
        guard let cfArray = copySpaces(conn) else { return [] }
        let array = cfArray as [AnyObject]
        return array.compactMap { $0 as? [String: Any] }
    }
}
