import Testing
@testable import NTFSCore

@Suite struct EnvironmentTests {
    private func report(_ v: String? = "5.5.0", ntfs3g: String? = "/opt/homebrew/bin/ntfs-3g", paragon: Bool = false) -> EnvironmentReport {
        EnvironmentReport(macFUSEVersion: v, ntfs3gPath: ntfs3g, paragonPresent: paragon)
    }

    @Test func everythingFineHasNoProblems() {
        #expect(problems(in: report()).isEmpty)
    }

    @Test func oldMacFUSEIsFlaggedWithItsVersion() {
        #expect(problems(in: report("4.6.0")) == [.macFUSETooOld("4.6.0")])
    }

    @Test func missingMacFUSE() {
        #expect(problems(in: report(nil)) == [.macFUSEMissing])
    }

    @Test func versionComparisonIsNumericNotLexical() {
        #expect(problems(in: report("10.0")).isEmpty)
        #expect(problems(in: report("5.0.0")).isEmpty)
        #expect(problems(in: report("4.10.0")) == [.macFUSETooOld("4.10.0")])
    }

    @Test func missingNtfs3g() {
        #expect(problems(in: report(ntfs3g: nil)) == [.ntfs3gMissing])
    }

    @Test func paragonDriverIsAConflict() {
        #expect(problems(in: report(paragon: true)) == [.paragonConflict])
    }

    @Test func problemsComeInSetupOrder() {
        #expect(problems(in: report(nil, ntfs3g: nil, paragon: true)) == [.macFUSEMissing, .ntfs3gMissing, .paragonConflict])
    }

    @Test func inspectUsesFileChecksAndVersionReader() {
        let r = inspectEnvironment(
            fileExists: { $0 == "/opt/homebrew/bin/ntfs-3g" || $0 == "/Library/Filesystems/ufsd_NTFS.fs" },
            readVersion: { "5.5.0" })
        #expect(r == EnvironmentReport(macFUSEVersion: "5.5.0", ntfs3gPath: "/opt/homebrew/bin/ntfs-3g", paragonPresent: true))
    }
}
