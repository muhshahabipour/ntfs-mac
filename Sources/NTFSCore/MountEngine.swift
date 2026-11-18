import Foundation
import os

public enum MountError: Error, Equatable, Sendable, Codable {
    case invalidDevice
    case busy(holders: [String])
    case notClean(VolumeHealth)
    case toolMissing
    case failed(String)
    /// ntfs-3g started but no mount appeared: the macFUSE FSKit extension is most likely not enabled.
    case extensionNotEnabled
    /// macOS refused raw access to the disk (TCC): the app needs Full Disk Access.
    case diskAccessDenied
}

public struct ToolPaths: Sendable {
    public var ntfs3g = "/opt/homebrew/bin/ntfs-3g"
    public var probe = "/opt/homebrew/bin/ntfs-3g.probe"
    public var ntfsfix = "/opt/homebrew/bin/ntfsfix"
    public var mkntfs = "/opt/homebrew/sbin/mkntfs"
    public var diskutil = "/usr/sbin/diskutil"
    public var mount = "/sbin/mount"
    public var lsof = "/usr/sbin/lsof"
    public init() {}
}

public struct FileOps: Sendable {
    public var makeDirectory: @Sendable (String) throws -> Void
    public var removeDirectory: @Sendable (String) -> Void   // non-recursive: only removes an empty directory

    public init(makeDirectory: @escaping @Sendable (String) throws -> Void,
                removeDirectory: @escaping @Sendable (String) -> Void) {
        self.makeDirectory = makeDirectory
        self.removeDirectory = removeDirectory
    }

    public static let live = FileOps(
        makeDirectory: { try FileManager.default.createDirectory(atPath: $0, withIntermediateDirectories: false) },
        removeDirectory: { _ = rmdir($0) })
}

/// Must run as root (inside the privileged helper). Holds no UI knowledge.
public actor MountEngine {
    private let runner: ProcessRunning
    private let tools: ToolPaths
    private let files: FileOps
    private let verifyAttempts: Int
    private let sleep: @Sendable (Duration) async -> Void
    private var mounted: [String: String] = [:]   // disk id -> mount point

    public init(runner: ProcessRunning = SystemProcessRunner(),
                tools: ToolPaths = ToolPaths(),
                files: FileOps = .live,
                verifyAttempts: Int = 20,
                sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.runner = runner; self.tools = tools; self.files = files
        self.verifyAttempts = verifyAttempts; self.sleep = sleep
    }

    public func probe(_ disk: NTFSDisk) async throws -> VolumeHealth {
        guard isValidDiskDevice(disk.deviceNode) else { throw MountError.invalidDevice }
        let r = try await exec(tools.probe, ["--readwrite", disk.deviceNode])
        // macOS blocks the helper from opening the device without Full Disk Access; ntfs-3g.probe then
        // exits 14, which would otherwise be misread as "hibernated".
        if r.status != 0, r.stderr.contains("Operation not permitted") { throw MountError.diskAccessDenied }
        Logger(subsystem: "com.local.ntfs", category: "probe")
            .notice("probe \(disk.deviceNode, privacy: .public) status=\(r.status) stderr=\(r.stderr, privacy: .public) stdout=\(r.stdout, privacy: .public)")
        return classifyHealth(probeStatus: r.status)
    }

    /// Mounts read/write only a clean volume. Returns the mount point.
    public func mountReadWrite(_ disk: NTFSDisk) async throws -> String {
        let health = try await probe(disk)
        guard health.canMountReadWrite else { throw MountError.notClean(health) }

        // Never run a second ntfs-3g on a device that one of ours already serves (e.g. after the app restarted):
        // two writers on one NTFS volume corrupt it. Adopt the existing mount instead.
        if let existing = try await macFUSEMountPoint(of: disk.deviceNode) {
            mounted[disk.id] = existing
            return existing
        }

        let mp = mountPoint(for: disk, taken: Set(mounted.values))
        do { try files.makeDirectory(mp) } catch { throw MountError.failed("\(error)") }
        mounted[disk.id] = mp

        let result: ProcessResult
        do {
            result = try await exec(tools.ntfs3g,
                ntfs3gArguments(device: disk.deviceNode, mountPoint: mp, volname: sanitizedName(String(mp.dropFirst("/Volumes/".count)))))
        } catch { forget(disk.id); throw error }
        guard result.status == 0 else {
            forget(disk.id)
            if result.stderr.contains("Operation not permitted") { throw MountError.diskAccessDenied }
            throw MountError.failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        for _ in 0..<verifyAttempts {
            if let table = try? await exec(tools.mount, []), table.stdout.contains(" on \(mp) (") { return mp }
            await sleep(.milliseconds(500))
        }
        forget(disk.id)
        throw MountError.extensionNotEnabled
    }

    private func macFUSEMountPoint(of device: String) async throws -> String? {
        guard let table = try? await exec(tools.mount, []) else { return nil }
        for line in table.stdout.split(separator: "\n") where line.hasPrefix("\(device) on ") && line.contains("macfuse") {
            let rest = line.dropFirst(device.count + 4)
            if let end = rest.range(of: " (", options: .backwards) { return String(rest[..<end.lowerBound]) }
        }
        return nil
    }

    /// Unmounts macOS's own read-only mount so ntfs-3g can take the device.
    public func releaseNativeMount(_ disk: NTFSDisk) async throws {
        guard isValidDiskDevice(disk.deviceNode) else { throw MountError.invalidDevice }
        let r = try await exec(tools.diskutil, ["unmount", disk.deviceNode])
        guard r.status == 0 else { throw MountError.failed(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// `ntfsfix -d` — only for a volume that is dirty (never hibernated or otherwise unsafe).
    public func repair(_ disk: NTFSDisk) async throws {
        let health = try await probe(disk)
        guard health.isRepairable else { throw MountError.notClean(health) }
        let r = try await exec(tools.ntfsfix, ["-d", disk.deviceNode])
        guard r.status == 0 else { throw MountError.failed(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    public func unmount(_ disk: NTFSDisk) async throws {
        guard isValidDiskDevice(disk.deviceNode) else { throw MountError.invalidDevice }
        // After a helper restart we no longer know the mount point; the device node works as well.
        let mp = mounted[disk.id] ?? disk.deviceNode
        let r = try await exec(tools.diskutil, ["unmount", mp])
        if r.status != 0 {
            let holders = Self.holders(from: (try? await exec(tools.lsof, ["-Fc", "+D", mp]))?.stdout ?? "")
            if !holders.isEmpty { throw MountError.busy(holders: holders) }
            throw MountError.failed(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        forget(disk.id)
    }

    /// Quick-formats an *external NTFS partition* (never an internal disk, whole disk, or other filesystem).
    public func erase(_ disk: NTFSDisk, label: String) async throws {
        guard disk.deviceNode.wholeMatch(of: /\/dev\/disk[0-9]+s[0-9]+/) != nil else { throw MountError.invalidDevice }
        let info = try await exec(tools.diskutil, ["info", "-plist", disk.deviceNode])
        guard info.status == 0,
              let plist = try? PropertyListSerialization.propertyList(from: Data(info.stdout.utf8), format: nil) as? [String: Any],
              (plist["Internal"] as? Bool) == false,
              (plist["Content"] as? String) == "Windows_NTFS" else { throw MountError.invalidDevice }

        do { try await unmount(disk) } catch MountError.failed { /* not mounted: mkntfs refuses a busy device itself */ }
        let r = try await exec(tools.mkntfs, ["-F", "-Q", "-L", ntfsLabel(label), disk.deviceNode])
        guard r.status == 0 else { throw MountError.failed(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// The disk was pulled out: run no commands, just clean up our bookkeeping.
    public func diskDisappeared(id: String) { forget(id) }

    private func forget(_ id: String) {
        if let mp = mounted.removeValue(forKey: id) { files.removeDirectory(mp) }
    }

    private func exec(_ exe: String, _ args: [String]) async throws -> ProcessResult {
        do { return try await runner.run(exe, args) } catch { throw MountError.toolMissing }
    }

    private static func holders(from lsofOutput: String) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for line in lsofOutput.split(separator: "\n") where line.hasPrefix("c") {
            let name = String(line.dropFirst())
            if seen.insert(name).inserted { out.append(name) }
        }
        return out
    }
}
