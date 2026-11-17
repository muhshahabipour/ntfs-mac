import Testing
@testable import NTFSCore

@Suite struct IOKitCounterTests {
    @Test func unknownDeviceIsNil() {
        #expect(IOKitCounterSource().totalBytes(for: "disk999s9") == nil)
    }

    /// Smoke test against the built-in disk; may legitimately be nil on hardware without IOBlockStorageDriver.
    @Test func builtInDiskReportsCountersOrNil() {
        let a = IOKitCounterSource().totalBytes(for: "disk0")
        print("disk0 total bytes:", a as Any)
        if let a { #expect(a > 0) }
    }
}
