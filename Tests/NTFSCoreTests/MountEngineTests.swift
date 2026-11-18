import Foundation
import Synchronization
import Testing
@testable import NTFSCore

final class FakeFileOps: Sendable {
    private let state = Mutex<(made: [String], removed: [String])>((made: [], removed: []))
    var made: [String] { state.withLock { $0.made } }
    var removed: [String] { state.withLock { $0.removed } }
    var ops: FileOps {
        FileOps(makeDirectory: { p in self.state.withLock { $0.made.append(p) } },
                removeDirectory: { p in self.state.withLock { $0.removed.append(p) } })
    }
}

private let disk = NTFSDisk(id: "disk4s1", label: "Backup", sizeBytes: 2_000_000_000_000, deviceNode: "/dev/disk4s1")
private func mountTable(_ mp: String) -> ProcessResult {
    ProcessResult(status: 0, stdout: "/dev/disk4s1 on \(mp) (macfuse, local, nodev, synchronous)\n")
}

@Suite struct MountPointTests {
    @Test func sanitisesSlashQuotesAndCommas() {
        let mp = mountPoint(for: NTFSDisk(id: "d", label: "a/b\"c,d", sizeBytes: 0, deviceNode: "/dev/d"), taken: [])
        let last = String(mp.dropFirst("/Volumes/".count))
        #expect(mp.hasPrefix("/Volumes/"))
        #expect(!last.contains("/") && !last.contains("\"") && !last.contains(","))
        #expect(!last.isEmpty)
    }

    @Test func duplicateLabelsGetSuffix() {
        #expect(mountPoint(for: disk, taken: []) == "/Volumes/Backup")
        #expect(mountPoint(for: disk, taken: ["/Volumes/Backup"]) == "/Volumes/Backup 2")
        #expect(mountPoint(for: disk, taken: ["/Volumes/Backup", "/Volumes/Backup 2"]) == "/Volumes/Backup 3")
    }

    @Test func unlabeledAndDotLabelsFallBackToNTFS() {
        for label in [nil, "", "   ", "..", "."] as [String?] {
            let d = NTFSDisk(id: "d", label: label, sizeBytes: 0, deviceNode: "/dev/d")
            #expect(mountPoint(for: d, taken: []) == "/Volumes/NTFS")
        }
    }

    @Test func persianLabelIsKept() {
        let d = NTFSDisk(id: "d", label: "پشتیبان", sizeBytes: 0, deviceNode: "/dev/d")
        #expect(mountPoint(for: d, taken: []) == "/Volumes/پشتیبان")
    }

    @Test func argumentsAreSeparateArgvEntries() {
        let args = ntfs3gArguments(device: "/dev/disk4s1", mountPoint: "/Volumes/My Disk", volname: "My Disk")
        #expect(args == ["/dev/disk4s1", "/Volumes/My Disk", "-o", "local,rw,volname=My Disk"])
    }
}

@Suite struct MountEngineTests {
    private func engine(_ runner: FakeProcessRunner, files: FakeFileOps = FakeFileOps()) -> MountEngine {
        MountEngine(runner: runner, files: files.ops, verifyAttempts: 2, mountOptions: [], sleep: { _ in })
    }

    @Test func mountsCleanDiskReadWrite() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0),                 // probe
            ProcessResult(status: 0),                 // existing mount table (none)
            ProcessResult(status: 0),                 // ntfs-3g
            mountTable("/Volumes/Backup"),            // mount table
        ])
        let files = FakeFileOps()
        let mp = try await engine(runner, files: files).mountReadWrite(disk)
        #expect(mp == "/Volumes/Backup")
        #expect(files.made == ["/Volumes/Backup"])
        #expect(runner.calls[2].arguments == ["/dev/disk4s1", "/Volumes/Backup", "-o", "local,rw,volname=Backup"])
    }

    @Test func refusesDirtyDiskAndNeverCallsNtfs3g() async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 15)])
        await #expect(throws: MountError.notClean(.dirty)) { try await engine(runner).mountReadWrite(disk) }
        #expect(runner.calls.count == 1)
    }

    @Test func tccDenialIsNotMistakenForHibernation() async {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 14, stderr: "Error opening '/dev/disk4s1': Operation not permitted\n")])
        await #expect(throws: MountError.diskAccessDenied) { try await engine(runner).mountReadWrite(disk) }
        #expect(runner.calls.count == 1)
    }

    @Test func unmountWorksByDeviceWhenMountPointIsUnknown() async throws {
        let runner = FakeProcessRunner()
        try await engine(runner).unmount(disk)
        #expect(runner.calls == [.init(executable: "/usr/sbin/diskutil", arguments: ["unmount", "/dev/disk4s1"])])
    }

    private func infoPlist(internal isInternal: Bool, content: String) -> ProcessResult {
        ProcessResult(status: 0, stdout: """
        <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
        <key>Internal</key><\(isInternal ? "true" : "false")/>
        <key>Content</key><string>\(content)</string></dict></plist>
        """)
    }

    @Test func eraseUnmountsThenFormatsAnExternalNTFSPartition() async throws {
        let runner = FakeProcessRunner(results: [infoPlist(internal: false, content: "Windows_NTFS"), ProcessResult(status: 0), ProcessResult(status: 0)])
        try await engine(runner).erase(disk, label: "  Photos ")
        #expect(runner.calls.map(\.arguments) == [["info", "-plist", "/dev/disk4s1"], ["unmount", "/dev/disk4s1"],
                                                  ["-F", "-Q", "-L", "Photos", "/dev/disk4s1"]])
        #expect(runner.calls.last?.executable == "/opt/homebrew/sbin/mkntfs")
    }

    @Test func eraseRefusesInternalDisksOtherFilesystemsAndWholeDisks() async {
        for result in [infoPlist(internal: true, content: "Windows_NTFS"), infoPlist(internal: false, content: "Apple_APFS")] {
            let runner = FakeProcessRunner(results: [result])
            await #expect(throws: MountError.invalidDevice) { try await engine(runner).erase(disk, label: "X") }
            #expect(runner.calls.count == 1)
        }
        let whole = NTFSDisk(id: "disk4", label: nil, sizeBytes: 1, deviceNode: "/dev/disk4")
        let runner = FakeProcessRunner()
        await #expect(throws: MountError.invalidDevice) { try await engine(runner).erase(whole, label: "X") }
        #expect(runner.calls.isEmpty)
    }

    @Test func labelsAreCleaned() {
        #expect(ntfsLabel("") == "NTFS")
        #expect(ntfsLabel("  a\nb ") == "ab")
        #expect(ntfsLabel(String(repeating: "x", count: 50)).count == 32)
    }

    @Test func anExistingMacFUSEMountIsAdoptedNotMountedTwice() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0),                                  // probe
            mountTable("/Volumes/My Disk"),                            // already served by ntfs-3g
        ])
        let mp = try await engine(runner).mountReadWrite(disk)
        #expect(mp == "/Volumes/My Disk")
        #expect(runner.calls.count == 2)   // no ntfs-3g launched
    }

    @Test func missingExtensionIsReportedWhenMountNeverAppears() async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 0)],
                                       fallback: ProcessResult(status: 0, stdout: "/dev/disk3s1 on / (apfs)\n"))
        let files = FakeFileOps()
        await #expect(throws: MountError.extensionNotEnabled) { try await engine(runner, files: files).mountReadWrite(disk) }
        #expect(files.removed == ["/Volumes/Backup"])
    }

    @Test func ntfs3gFailureSurfacesStderrAndCleansUp() async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 1, stderr: "boom")])
        let files = FakeFileOps()
        await #expect(throws: MountError.failed("boom")) { try await engine(runner, files: files).mountReadWrite(disk) }
        #expect(files.removed == ["/Volumes/Backup"])
    }

    @Test func repairRunsNtfsfixOnlyForDirtyDisks() async throws {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 15), ProcessResult(status: 0)])
        try await engine(runner).repair(disk)
        #expect(runner.calls[1].arguments == ["-d", "/dev/disk4s1"])
    }

    @Test(arguments: [Int32(14), 13, 12, 16])
    func repairRefusesEverythingElse(status: Int32) async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: status)])
        await #expect(throws: MountError.self) { try await engine(runner).repair(disk) }
        #expect(runner.calls.count == 1)   // ntfsfix never ran
    }

    @Test func twoDisksWithSameLabelGetDistinctMountPoints() async throws {
        let other = NTFSDisk(id: "disk5s1", label: "Backup", sizeBytes: 1, deviceNode: "/dev/disk5s1")
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 0), mountTable("/Volumes/Backup"),
            ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 0), mountTable("/Volumes/Backup 2"),
        ])
        let e = engine(runner)
        #expect(try await e.mountReadWrite(disk) == "/Volumes/Backup")
        #expect(try await e.mountReadWrite(other) == "/Volumes/Backup 2")
    }

    @Test func unmountReportsBusyHolders() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 0), mountTable("/Volumes/Backup"),     // mount
            ProcessResult(status: 1, stderr: "Volume Backup failed to unmount: dissented by PID 123 (Finder)"),
            ProcessResult(status: 0, stdout: "cFinder\ncPreview\ncFinder\n"),                      // lsof -Fc
        ])
        let e = engine(runner)
        _ = try await e.mountReadWrite(disk)
        await #expect(throws: MountError.busy(holders: ["Finder", "Preview"])) { try await e.unmount(disk) }
    }

    @Test func unmountSuccessRemovesMountPoint() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 0), mountTable("/Volumes/Backup"),
            ProcessResult(status: 0),
        ])
        let files = FakeFileOps()
        let e = engine(runner, files: files)
        _ = try await e.mountReadWrite(disk)
        try await e.unmount(disk)
        #expect(runner.calls.last?.arguments == ["unmount", "/Volumes/Backup"])
        #expect(files.removed == ["/Volumes/Backup"])
    }

    @Test func disappearedDiskIsForgottenAndItsMountPointRemoved() async throws {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 0), ProcessResult(status: 0), ProcessResult(status: 0), mountTable("/Volumes/Backup")])
        let files = FakeFileOps()
        let e = engine(runner, files: files)
        _ = try await e.mountReadWrite(disk)
        await e.diskDisappeared(id: "disk4s1")
        #expect(files.removed == ["/Volumes/Backup"])
        #expect(runner.calls.count == 4)   // no commands run for a vanished disk
    }
}

@Suite struct MountOptionTests {
    @Test func extraOptionsAreAppendedToTheOptionString() {
        #expect(ntfs3gArguments(device: "/dev/d", mountPoint: "/Volumes/x", volname: "x", extraOptions: ["allow_other", "uid=501"])
                == ["/dev/d", "/Volumes/x", "-o", "local,rw,volname=x,allow_other,uid=501"])
    }

    @Test func defaultOptionsEnableFinderCompatibility() {
        let options = defaultMountOptions()
        #expect(options.contains("allow_other"))
    }
}

@Suite struct VolumeLabelTests {
    @Test func unlabeledDiskIsMountedUnderItsRealVolumeName() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0),                                                    // probe
            ProcessResult(status: 0),                                                    // mount table
            ProcessResult(status: 0, stdout: "Volume Information\n\tVolume Name: Photos 2024\n\tVolume State: 0\n"), // ntfsinfo
            ProcessResult(status: 0),                                                    // ntfs-3g
            ProcessResult(status: 0, stdout: "/dev/disk4s1 on /Volumes/Photos 2024 (macfuse, local)\n"),
        ])
        let e = MountEngine(runner: runner, files: FakeFileOps().ops, verifyAttempts: 1, mountOptions: [], sleep: { _ in })
        let mp = try await e.mountReadWrite(NTFSDisk(id: "disk4s1", label: nil, sizeBytes: 1, deviceNode: "/dev/disk4s1"))
        #expect(mp == "/Volumes/Photos 2024")
    }
}
