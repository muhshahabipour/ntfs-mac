import Testing
@testable import NTFSCore

@Suite struct PersianFormatTests {
    @Test func sizes() {
        #expect(persianSize(1_200_000_000_000) == "۱.۲ ترابایت")
        #expect(persianSize(2_000_000_000_000) == "۲ ترابایت")
        #expect(persianSize(2_500_000_000_000) == "۲.۵ ترابایت")
        #expect(persianSize(100_000_000_000) == "۱۰۰ گیگابایت")
        #expect(persianSize(5_000_000) == "۵ مگابایت")
        #expect(persianSize(2_000) == "۲ کیلوبایت")
        #expect(persianSize(512) == "۵۱۲ بایت")
        #expect(persianSize(0) == "۰ بایت")
    }

    @Test func percents() {
        #expect(persianPercent(0.62) == "۶۲٪")
        #expect(persianPercent(0) == "۰٪")
        #expect(persianPercent(1) == "۱۰۰٪")
        #expect(persianPercent(1.7) == "۱۰۰٪")      // clamped
        #expect(persianPercent(-0.2) == "۰٪")
        #expect(persianPercent(.nan) == "۰٪")
    }

    @Test func speeds() {
        #expect(persianSpeed(185_000_000) == "۱۸۵ مگابایت بر ثانیه")
        #expect(persianSpeed(2_000_000_000) == "۲۰۰۰ مگابایت بر ثانیه")
        #expect(persianSpeed(800_000) == "۸۰۰ کیلوبایت بر ثانیه")
        #expect(persianSpeed(0) == "۰ کیلوبایت بر ثانیه")
    }

    @Test func digitsOnly() {
        #expect(persianDigits("12:30 ab 9") == "۱۲:۳۰ ab ۹")
    }
}

@Suite struct NativeMountTests {
    private let disk = NTFSDisk(id: "disk4s1", label: "Backup", sizeBytes: 1, deviceNode: "/dev/disk4s1")

    @Test func releaseUnmountsTheMacOSMount() async throws {
        let runner = FakeProcessRunner()
        let engine = MountEngine(runner: runner, files: FakeFileOps().ops, verifyAttempts: 1, sleep: { _ in })
        try await engine.releaseNativeMount(disk)
        #expect(runner.calls == [.init(executable: "/usr/sbin/diskutil", arguments: ["unmount", "/dev/disk4s1"])])
    }

    @Test func releaseFailureIsReported() async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 1, stderr: "busy")])
        let engine = MountEngine(runner: runner, files: FakeFileOps().ops, verifyAttempts: 1, sleep: { _ in })
        await #expect(throws: MountError.failed("busy")) { try await engine.releaseNativeMount(disk) }
    }

    @Test func serviceRoutesReleaseRequest() async {
        let runner = FakeProcessRunner()
        let svc = HelperService(engine: MountEngine(runner: runner, files: FakeFileOps().ops, verifyAttempts: 1, sleep: { _ in }))
        #expect(await svc.handle(.releaseNative(device: "/dev/disk4s1")) == .done)
        #expect(await svc.handle(.releaseNative(device: "/dev/disk4; x")) == .failure(.invalidDevice))
    }

    @Test func parserFlagsNativelyMountedVolumes() {
        let d: [String: Any] = ["DAVolumeKind": "ntfs", "DAVolumePath": "file:///Volumes/Backup/", "DAMediaSize": 10]
        #expect(ntfsDisk(from: d, bsdName: "disk4s1")?.nativelyMounted == true)
    }
}

@Suite struct EnglishFormatTests {
    @Test func sizes() {
        #expect(englishSize(1_200_000_000_000) == "1.2 TB")
        #expect(englishSize(2_000_000_000_000) == "2 TB")
        #expect(englishSize(100_000_000_000) == "100 GB")
        #expect(englishSize(5_000_000) == "5 MB")
        #expect(englishSize(2_000) == "2 KB")
        #expect(englishSize(512) == "512 B")
        #expect(englishSize(0) == "0 B")
    }

    @Test func percents() {
        #expect(englishPercent(0.62) == "62%")
        #expect(englishPercent(1.7) == "100%")
        #expect(englishPercent(.nan) == "0%")
    }

    @Test func speeds() {
        #expect(englishSpeed(185_000_000) == "185 MB/s")
        #expect(englishSpeed(800_000) == "800 KB/s")
        #expect(englishSpeed(0) == "0 KB/s")
    }
}
