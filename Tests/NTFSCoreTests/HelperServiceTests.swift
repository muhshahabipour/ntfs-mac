import Foundation
import Testing
@testable import NTFSCore

@Suite struct DeviceValidationTests {
    @Test(arguments: ["/dev/disk4", "/dev/disk4s1", "/dev/disk12s10"])
    func acceptsWholeDisksAndPartitions(path: String) {
        #expect(isValidDiskDevice(path))
    }

    @Test(arguments: ["", "/dev/disk", "/dev/disk4s", "/dev/rdisk4", "/dev/disk4s1/../disk0",
                      "../dev/disk4", "/dev/disk4 ", "/dev/disk4\n", "--foo", "-o", "/dev/disk4s1;rm",
                      "/dev/disk4s1 /Volumes/x", "/Volumes/Backup", "disk4s1"])
    func rejectsEverythingElse(path: String) {
        #expect(!isValidDiskDevice(path))
    }
}

@Suite struct HelperServiceTests {
    private func service(_ runner: FakeProcessRunner) -> HelperService {
        HelperService(engine: MountEngine(runner: runner, files: FakeFileOps().ops, verifyAttempts: 1, sleep: { _ in }))
    }

    @Test func probeReturnsHealth() async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 15)])
        let r = await service(runner).handle(.probe(device: "/dev/disk4s1"))
        #expect(r == .health(.dirty))
    }

    @Test func mountReturnsMountPoint() async {
        let runner = FakeProcessRunner(results: [
            ProcessResult(status: 0), ProcessResult(status: 0),
            ProcessResult(status: 0, stdout: "/dev/disk4s1 on /Volumes/Backup (macfuse, local)\n"),
        ])
        let r = await service(runner).handle(.mount(device: "/dev/disk4s1", label: "Backup"))
        #expect(r == .mounted(mountPoint: "/Volumes/Backup"))
    }

    @Test func dirtyDiskMountIsRefusedAsFailure() async {
        let runner = FakeProcessRunner(results: [ProcessResult(status: 15)])
        let r = await service(runner).handle(.mount(device: "/dev/disk4s1", label: nil))
        #expect(r == .failure(.notClean(.dirty)))
    }

    @Test(arguments: ["--foo", "/dev/disk4s1; rm -rf /", "../../etc/passwd", "/Volumes/X"])
    func invalidDevicesNeverReachAnyTool(device: String) async {
        let runner = FakeProcessRunner()
        let svc = service(runner)
        for req in [HelperRequest.probe(device: device), .mount(device: device, label: "x"),
                    .repair(device: device), .unmount(device: device), .diskGone(device: device)] {
            let r = await svc.handle(req)
            #expect(r == .failure(.invalidDevice))
        }
        #expect(runner.calls.isEmpty)
    }

    @Test func garbageBytesGiveAFailureNotACrash() async throws {
        let data = await service(FakeProcessRunner()).handle(Data("not json".utf8))
        let r = try JSONDecoder().decode(HelperResponse.self, from: data)
        guard case .failure = r else { Issue.record("expected failure"); return }
    }

    @Test func requestAndResponseSurviveJSONRoundTrip() async throws {
        let req = HelperRequest.mount(device: "/dev/disk4s1", label: "پشتیبان")
        let back = try JSONDecoder().decode(HelperRequest.self, from: JSONEncoder().encode(req))
        #expect(back == req)
        for r in [HelperResponse.health(.hibernated), .mounted(mountPoint: "/Volumes/a"), .done,
                  .failure(.busy(holders: ["Finder"])), .failure(.extensionNotEnabled)] {
            #expect(try JSONDecoder().decode(HelperResponse.self, from: JSONEncoder().encode(r)) == r)
        }
    }
}
