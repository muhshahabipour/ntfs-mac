import Foundation

public enum MountError: Error, Equatable, Sendable, Codable {
    case invalidDevice
    case busy(holders: [String])
    case notClean(VolumeHealth)
    case toolMissing
    case failed(String)
    /// ntfs-3g started but no mount appeared: the macFUSE FSKit extension is most likely not enabled.
    case extensionNotEnabled
}

public struct ToolPaths: Sendable {
    public var ntfs3g = "/opt/homebrew/bin/ntfs-3g"
    public var probe = "/opt/homebrew/bin/ntfs-3g.probe"
    public var ntfsfix = "/opt/homebrew/bin/ntfsfix"
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
        return classifyHealth(probeStatus: try await exec(tools.probe, ["--readwrite", disk.deviceNode]).status)
    }

    /// Mounts read/write only a clean volume. Returns the mount point.
    public func mountReadWrite(_ disk: NTFSDisk) async throws -> String {
        let health = try await probe(disk)
        guard health.canMountReadWrite else { throw MountError.notClean(health) }

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
            throw MountError.failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        for _ in 0..<verifyAttempts {
            if let table = try? await exec(tools.mount, []), table.stdout.contains(" on \(mp) (") { return mp }
            await sleep(.milliseconds(500))
        }
        forget(disk.id)
        throw MountError.extensionNotEnabled
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
        guard let mp = mounted[disk.id] else { return }
        let r = try await exec(tools.diskutil, ["unmount", mp])
        if r.status != 0 {
            let holders = Self.holders(from: (try? await exec(tools.lsof, ["-Fc", "+D", mp]))?.stdout ?? "")
            if !holders.isEmpty { throw MountError.busy(holders: holders) }
            throw MountError.failed(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        forget(disk.id)
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
