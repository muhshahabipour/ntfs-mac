import DiskArbitration
import Foundation

public struct NTFSDisk: Equatable, Identifiable, Sendable {
    /// BSD name, e.g. "disk4s1".
    public let id: String
    public let label: String?
    public let sizeBytes: UInt64
    public let deviceNode: String
    /// macOS's own (read-only) NTFS driver already mounted it; we must release that before our read/write mount.
    public let nativelyMounted: Bool

    public init(id: String, label: String?, sizeBytes: UInt64, deviceNode: String, nativelyMounted: Bool = false) {
        self.id = id; self.label = label; self.sizeBytes = sizeBytes; self.deviceNode = deviceNode
        self.nativelyMounted = nativelyMounted
    }
}

public enum DiskEvent: Equatable, Sendable {
    case appeared(NTFSDisk)
    case disappeared(id: String)
}

public protocol DiskEventSource: Sendable {
    var events: AsyncStream<DiskEvent> { get }
}

/// Returns an `NTFSDisk` for external NTFS volumes, nil for everything else.
/// `description` is the dictionary from `DADiskCopyDescription`, keyed by plain strings.
public func ntfsDisk(from description: [String: Any], bsdName: String) -> NTFSDisk? {
    if (description["DADeviceInternal"] as? Bool) == true { return nil }   // never touch internal drives

    let kind = description["DAVolumeKind"] as? String
    let content = description["DAMediaContent"] as? String
    // "ufsd_NTFS" is Paragon's driver: it mounts NTFS itself, so treat it like macOS's native mount (we release it).
    guard kind == "ntfs" || kind == "ufsd_NTFS" || (kind == nil && content == "Windows_NTFS") else { return nil }

    let label = (description["DAVolumeName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let size = (description["DAMediaSize"] as? NSNumber)?.uint64Value ?? 0
    return NTFSDisk(id: bsdName, label: label, sizeBytes: size, deviceNode: "/dev/\(bsdName)",
                    nativelyMounted: description["DAVolumePath"] != nil)
}

/// DiskArbitration-backed event source. Verified manually (Task 10), not unit-tested.
public final class DiskArbitrationSource: DiskEventSource, @unchecked Sendable {
    public let events: AsyncStream<DiskEvent>
    private let session: DASession
    private let queue = DispatchQueue(label: "ntfs.diskarbitration")

    public init() {
        let session = DASessionCreate(kCFAllocatorDefault)!
        self.session = session
        var continuation: AsyncStream<DiskEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        let box = Unmanaged.passRetained(ContinuationBox(continuation))

        DARegisterDiskDescriptionChangedCallback(session, nil, nil, { disk, _, ctx in
            handleDiskAppeared(disk, ctx)
        }, box.toOpaque())
        DARegisterDiskAppearedCallback(session, nil, { disk, ctx in
            handleDiskAppeared(disk, ctx)
        }, box.toOpaque())
        DARegisterDiskDisappearedCallback(session, nil, { disk, ctx in
            guard let ctx, let name = DADiskGetBSDName(disk).map({ String(cString: $0) }) else { return }
            Unmanaged<ContinuationBox>.fromOpaque(ctx).takeUnretainedValue().continuation.yield(.disappeared(id: name))
        }, box.toOpaque())
        DASessionSetDispatchQueue(session, queue)
    }

    deinit { DASessionSetDispatchQueue(session, nil) }

}

private func handleDiskAppeared(_ disk: DADisk, _ ctx: UnsafeMutableRawPointer?) {
        guard let ctx,
              let name = DADiskGetBSDName(disk).map({ String(cString: $0) }),
              let cf = DADiskCopyDescription(disk) as? [String: Any],
              let ntfs = ntfsDisk(from: cf, bsdName: name) else { return }
        Unmanaged<ContinuationBox>.fromOpaque(ctx).takeUnretainedValue().continuation.yield(.appeared(ntfs))
}

private final class ContinuationBox: @unchecked Sendable {
    let continuation: AsyncStream<DiskEvent>.Continuation
    init(_ c: AsyncStream<DiskEvent>.Continuation) { continuation = c }
}
