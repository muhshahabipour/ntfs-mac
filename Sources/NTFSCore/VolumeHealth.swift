import Foundation

public enum VolumeHealth: Equatable, Sendable, Codable {
    case clean
    /// Not cleanly unmounted (typically Windows Fast Startup). Repairable with `ntfsfix`, with user consent.
    case dirty
    /// Windows hibernated. Never repair from the Mac: the user must boot Windows and shut down fully.
    case hibernated
    /// Inconsistent or needs a Windows chkdsk.
    case needsWindowsCheck
    case notNTFS
    /// Already opened exclusively by another driver (e.g. Paragon).
    case inUse
    case unknown

    public var isRepairable: Bool { self == .dirty }
    public var canMountReadWrite: Bool { self == .clean }
}

/// Maps `ntfs-3g.probe --readwrite` exit codes (see its man page) to a health state.
public func classifyHealth(probeStatus: Int32) -> VolumeHealth {
    switch probeStatus {
    case 0: .clean
    case 12: .notNTFS
    case 13, 17: .needsWindowsCheck
    case 14: .hibernated
    case 15: .dirty
    case 16: .inUse
    default: .unknown
    }
}
