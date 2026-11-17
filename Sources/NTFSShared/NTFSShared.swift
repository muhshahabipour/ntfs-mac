import Foundation

public enum HelperConstants {
    public static let machService = "com.local.ntfs.helper"
    public static let appIdentifier = "com.local.ntfs"
    public static let helperIdentifier = "com.local.ntfs.helper"
    public static let daemonPlistName = "com.local.ntfs.helper.plist"
    /// Personal-use build: signed with this Apple Development team.
    public static let teamID = "ZP5Y7UXW72"

    private static func requirement(for identifier: String) -> String {
        "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(teamID)\""
    }
    /// What the helper demands of its client.
    public static var clientRequirement: String { requirement(for: appIdentifier) }
    /// What the app demands of the helper it talks to.
    public static var helperRequirement: String { requirement(for: helperIdentifier) }
}

/// The whole XPC surface: JSON bytes in, JSON bytes out (see `HelperRequest` / `HelperResponse` in NTFSCore).
@objc public protocol NTFSHelperXPC {
    func send(_ request: Data, reply: @escaping @Sendable (Data) -> Void)
}
