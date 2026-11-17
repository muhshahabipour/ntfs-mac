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
public func ntfs3gArguments(device: String, mountPoint: String, volname: String) -> [String] {
    [device, mountPoint, "-o", "local,rw,volname=\(volname)"]
}
