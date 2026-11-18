import Foundation

/// A label made safe to use as one path component and as an ntfs-3g `volname=` value.
func sanitizedName(_ label: String?) -> String {
    var s = (label ?? "").unicodeScalars
        .filter { !CharacterSet.controlCharacters.contains($0) }
        .map { Character($0) }
        .map { c -> Character in (c == "/" || c == ":") ? "-" : c }
        .filter { $0 != "\"" && $0 != "," && $0 != "\\" }
        .reduce(into: "") { $0.append($1) }
    s = s.trimmingCharacters(in: .whitespaces)
    while s.hasPrefix(".") { s.removeFirst() }
    s = s.trimmingCharacters(in: .whitespaces)
    if s.isEmpty { return "NTFS" }
    return String(s.prefix(100))
}

/// `/Volumes/<name>`, unique among `taken` (`name 2`, `name 3`, ...).
public func mountPoint(for disk: NTFSDisk, taken: Set<String>) -> String {
    let base = sanitizedName(disk.label)
    var candidate = "/Volumes/\(base)"
    var n = 2
    while taken.contains(candidate) {
        candidate = "/Volumes/\(base) \(n)"
        n += 1
    }
    return candidate
}

/// argv for `ntfs-3g` (never a shell string). Options verified in docs/spike-notes.md.
public func ntfs3gArguments(device: String, mountPoint: String, volname: String, extraOptions: [String] = []) -> [String] {
    let options = ["local", "rw", "volname=\(volname)"] + extraOptions
    return [device, mountPoint, "-o", options.joined(separator: ",")]
}

/// Options that make Finder copies work: files owned by the logged-in user, and macFUSE storing extended
/// attributes itself (NTFS via ntfs-3g has none), which Finder's copy otherwise fails on.
public func defaultMountOptions() -> [String] {
    var options = ["allow_other", "auto_xattr"]
    var info = stat()
    if stat("/dev/console", &info) == 0, info.st_uid != 0 {
        options += ["uid=\(info.st_uid)", "gid=\(info.st_gid)"]
    }
    return options
}

/// NTFS volume labels: at most 32 characters, no control characters; empty becomes "NTFS".
public func ntfsLabel(_ raw: String) -> String {
    let cleaned = raw.unicodeScalars.filter { !$0.properties.generalCategory.isControl }
    let text = String(String.UnicodeScalarView(cleaned)).trimmingCharacters(in: .whitespaces)
    return text.isEmpty ? "NTFS" : String(text.prefix(32))
}

private extension Unicode.GeneralCategory {
    var isControl: Bool { self == .control || self == .format || self == .lineSeparator || self == .paragraphSeparator }
}
