import Testing
@testable import NTFSCore

/// Exit codes are from the ntfs-3g.probe man page (EXIT CODES).
@Suite struct VolumeHealthTests {
    @Test(arguments: [
        (Int32(0), VolumeHealth.clean),
        (12, .notNTFS),
        (13, .needsWindowsCheck),
        (14, .hibernated),
        (15, .dirty),
        (16, .inUse),
        (17, .needsWindowsCheck),
    ])
    func mapsProbeExitCodes(status: Int32, expected: VolumeHealth) {
        #expect(classifyHealth(probeStatus: status) == expected)
    }

    @Test(arguments: [Int32(11), 18, 19, 20, 21, 99, -1])
    func otherNonZeroCodesAreUnknown(status: Int32) {
        #expect(classifyHealth(probeStatus: status) == .unknown)
    }

    @Test func onlyDirtyIsRepairable() {
        #expect(VolumeHealth.dirty.isRepairable)
        for h in [VolumeHealth.clean, .hibernated, .needsWindowsCheck, .notNTFS, .inUse, .unknown] {
            #expect(!h.isRepairable)
        }
    }

    @Test func onlyCleanIsWritable() {
        #expect(VolumeHealth.clean.canMountReadWrite)
        for h in [VolumeHealth.dirty, .hibernated, .needsWindowsCheck, .notNTFS, .inUse, .unknown] {
            #expect(!h.canMountReadWrite)
        }
    }
}
