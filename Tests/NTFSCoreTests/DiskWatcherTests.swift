import Testing
@testable import NTFSCore

@Suite struct DiskDescriptionParsingTests {
    private func desc(kind: String? = "ntfs", content: String? = nil, name: String? = "Backup",
                      size: Int = 2_000_000_000_000, isInternal: Bool = false) -> [String: Any] {
        var d: [String: Any] = ["DAMediaSize": size, "DADeviceInternal": isInternal]
        if let kind { d["DAVolumeKind"] = kind }
        if let content { d["DAMediaContent"] = content }
        if let name { d["DAVolumeName"] = name }
        return d
    }

    @Test func ntfsKindBecomesADisk() {
        let disk = ntfsDisk(from: desc(), bsdName: "disk4s1")
        #expect(disk == NTFSDisk(id: "disk4s1", label: "Backup", sizeBytes: 2_000_000_000_000, deviceNode: "/dev/disk4s1"))
    }

    @Test(arguments: ["hfs", "apfs", "exfat", "msdos", "macfuse"])
    func otherFilesystemsAreIgnored(kind: String) {
        #expect(ntfsDisk(from: desc(kind: kind), bsdName: "disk4s1") == nil)
    }

    @Test func mbrNTFSContentIsRecognisedWithoutVolumeKind() {
        #expect(ntfsDisk(from: desc(kind: nil, content: "Windows_NTFS"), bsdName: "disk5s1") != nil)
    }

    @Test func missingLabelIsNil() {
        #expect(ntfsDisk(from: desc(name: nil), bsdName: "disk4s1")?.label == nil)
    }

    @Test func persianLabelIsPreserved() {
        #expect(ntfsDisk(from: desc(name: "پشتیبان ۱"), bsdName: "disk4s1")?.label == "پشتیبان ۱")
    }

    @Test func internalDisksAreNeverTouched() {
        #expect(ntfsDisk(from: desc(isInternal: true), bsdName: "disk0s3") == nil)
    }

    @Test func unlabeledEmptyStringLabelIsNil() {
        #expect(ntfsDisk(from: desc(name: ""), bsdName: "disk4s1")?.label == nil)
    }
}
