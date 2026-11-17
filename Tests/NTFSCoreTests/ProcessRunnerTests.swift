import Testing
@testable import NTFSCore

@Suite struct ProcessRunnerTests {
    @Test func capturesStdoutAndStatus() async throws {
        let r = try await SystemProcessRunner().run("/bin/echo", ["hi"])
        #expect(r.stdout == "hi\n")
        #expect(r.status == 0)
    }

    @Test func capturesStderrAndNonZeroStatus() async throws {
        let r = try await SystemProcessRunner().run("/bin/sh", ["-c", "echo oops 1>&2; exit 3"])
        #expect(r.stderr == "oops\n")
        #expect(r.status == 3)
    }

    @Test func argumentsAreNotInterpretedByAShell() async throws {
        let r = try await SystemProcessRunner().run("/bin/echo", ["a; echo injected", "$HOME"])
        #expect(r.stdout == "a; echo injected $HOME\n")
    }
}
