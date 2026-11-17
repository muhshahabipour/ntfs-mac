import Foundation

public struct EnvironmentReport: Equatable, Sendable {
    public let macFUSEVersion: String?
    public let ntfs3gPath: String?
    public let paragonPresent: Bool

    public init(macFUSEVersion: String?, ntfs3gPath: String?, paragonPresent: Bool) {
        self.macFUSEVersion = macFUSEVersion; self.ntfs3gPath = ntfs3gPath; self.paragonPresent = paragonPresent
    }
}

public enum Problem: Equatable, Sendable {
    case macFUSEMissing
    case macFUSETooOld(String)
    case ntfs3gMissing
    case paragonConflict
}

/// macFUSE 5.x is the first line with the FSKit backend (see docs/spike-notes.md).
public let minimumMacFUSEVersion = [5, 0, 0]

private func versionComponents(_ v: String) -> [Int] {
    v.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
}

private func isOlder(_ v: String, than min: [Int]) -> Bool {
    let a = versionComponents(v)
    for i in 0..<max(a.count, min.count) {
        let x = i < a.count ? a[i] : 0, y = i < min.count ? min[i] : 0
        if x != y { return x < y }
    }
    return false
}

/// Problems in the order the first-run guide should walk the user through them.
public func problems(in report: EnvironmentReport) -> [Problem] {
    var out: [Problem] = []
    if let v = report.macFUSEVersion {
        if isOlder(v, than: minimumMacFUSEVersion) { out.append(.macFUSETooOld(v)) }
    } else {
        out.append(.macFUSEMissing)
    }
    if report.ntfs3gPath == nil { out.append(.ntfs3gMissing) }
    if report.paragonPresent { out.append(.paragonConflict) }
    return out
}

public func inspectEnvironment(fileExists: (String) -> Bool, readVersion: () -> String?) -> EnvironmentReport {
    let ntfs3g = ["/opt/homebrew/bin/ntfs-3g", "/usr/local/bin/ntfs-3g"].first(where: fileExists)
    return EnvironmentReport(
        macFUSEVersion: readVersion(),
        ntfs3gPath: ntfs3g,
        paragonPresent: fileExists("/Library/Filesystems/ufsd_NTFS.fs"))
}

public func inspectEnvironmentLive() -> EnvironmentReport {
    inspectEnvironment(
        fileExists: { FileManager.default.fileExists(atPath: $0) },
        readVersion: {
            let url = URL(fileURLWithPath: "/Library/Filesystems/macfuse.fs/Contents/Info.plist")
            let info = NSDictionary(contentsOf: url)
            return info?["CFBundleShortVersionString"] as? String
        })
}
