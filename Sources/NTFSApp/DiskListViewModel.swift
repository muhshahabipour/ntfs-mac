import AppKit
import Foundation
import NTFSCore
import Observation
import ServiceManagement

@MainActor @Observable
final class DiskListViewModel {
    struct Card: Identifiable {
        let id: String
        var disk: NTFSDisk
        var health: VolumeHealth = .unknown
        var mountPoint: String?
        var used: UInt64 = 0
        var bytesPerSecond = 0.0
        var isActive = false
        var busy: Busy?
        var errorText: String?
        var userUnmounted = false
    }
    enum Busy { case connecting, ejecting, unmounting, erasing }

    private(set) var cards: [Card] = []
    private(set) var problems: [Problem] = []
    private(set) var helperStatus: HelperStatus = .notRegistered
    private(set) var diskAccessDenied = false
    /// Full Disk Access is known to work once a disk has been mounted read/write.
    var diskAccessOK: Bool { diskAccessConfirmed && !diskAccessDenied }
    private var diskAccessConfirmed = UserDefaults.standard.bool(forKey: "diskAccessConfirmed")

    private let client = HelperClient()
    private let counters = IOKitCounterSource()
    private var source: DiskArbitrationSource?
    private var smoothers: [String: ThroughputSmoother] = [:]
    private var activeSince: [String: Date] = [:]
    private var detectors: [String: ActivityDetector] = [:]

    var needsAttention: Bool {
        cards.contains { if case .needsAttention = state(of: $0) { true } else { false } }
    }

    // MARK: lifecycle

    func start() {
        guard source == nil else { return }
        refreshEnvironment()
        let src = DiskArbitrationSource()
        source = src
        Task { [weak self] in
            for await event in src.events { self?.handle(event) }
        }
        Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: view data

    var cardModels: [DiskCardModel] {
        cards.map { DiskCardModel(id: $0.id, name: $0.disk.label ?? "NTFS",
                                  totalBytes: $0.disk.sizeBytes, usedBytes: $0.used, state: state(of: $0)) }
    }

    struct SetupStep: Identifiable {
        let id: String
        let title: String
        let detail: String
        let done: Bool
        var actionTitle: String?
    }

    /// The first-run checklist; empty once everything is in place.
    var setupSteps: [SetupStep] {
        let steps = [
            SetupStep(id: "macfuse", title: S.stepMacFUSE, detail: S.stepMacFUSEHow,
                      done: !problems.contains(.macFUSEMissing) && !problems.contains { if case .macFUSETooOld = $0 { true } else { false } }),
            SetupStep(id: "ntfs3g", title: S.stepNTFS3G, detail: S.stepNTFS3GHow, done: !problems.contains(.ntfs3gMissing)),
            SetupStep(id: "helper", title: S.stepHelper, detail: S.stepHelperHow, done: helperStatus == .enabled, actionTitle: S.enable),
            SetupStep(id: "diskAccess", title: S.stepAccess, detail: S.stepAccessHow, done: diskAccessOK, actionTitle: S.openSettings),
        ]
        return steps.allSatisfy(\.done) ? [] : steps
    }

    var setupItems: [SetupItem] {
        var items = problems.map { SetupItem(id: "problem", text: S.problem($0)) }
        switch helperStatus {
        case .enabled: break
        case .requiresApproval: items.append(SetupItem(id: "helper", text: S.helperNeedsApproval, action: S.enable))
        case .notRegistered: items.append(SetupItem(id: "helper", text: S.helperDisabled, action: S.enable))
        }
        if diskAccessDenied {
            items.append(SetupItem(id: "diskAccess", text: S.diskAccessDeniedText, action: S.openSettings))
        } else if !diskAccessConfirmed, helperStatus == .enabled {
            items.append(SetupItem(id: "diskAccess", text: S.diskAccessTip, action: S.openSettings))
        }
        return items
    }

    private func state(of c: Card) -> CardState {
        if c.busy == .ejecting { return .ejecting }
        if c.busy == .unmounting { return .unmounting }
        if c.busy == .erasing { return .erasing }
        if c.busy == .connecting { return .mounting }
        if let e = c.errorText { return .failed(e) }
        let speed = c.isActive ? max(c.bytesPerSecond, activityThresholdBytesPerSecond) : 0
        return cardState(health: c.health, mounted: c.mountPoint != nil, bytesPerSecond: speed,
                         used: c.used, total: c.disk.sizeBytes, userUnmounted: c.userUnmounted)
    }

    // MARK: events

    private func handle(_ event: DiskEvent) {
        switch event {
        case .appeared(let disk):
            if let i = cards.firstIndex(where: { $0.id == disk.id }) {
                // A native (macOS) mount reports the real volume label; ours would just echo what we chose.
                if disk.nativelyMounted, let label = disk.label, cards[i].mountPoint == nil, cards[i].disk.label != label {
                    cards[i].disk = disk
                }
                return
            }
            cards.append(Card(id: disk.id, disk: disk, busy: .connecting))
            Task { await connect(disk.id) }
        case .disappeared(let id):
            guard let card = cards.first(where: { $0.id == id }) else { return }
            cards.removeAll { $0.id == id }
            smoothers[id] = nil; detectors[id] = nil; activeSince[id] = nil
            Task { _ = try? await client.send(.diskGone(device: card.disk.deviceNode)) }
        }
    }

    private func update(_ id: String, _ change: (inout Card) -> Void) {
        guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
        change(&cards[i])
    }

    private func call(_ request: HelperRequest) async throws -> HelperResponse {
        let response = try await client.send(request)
        if case .failure(let e) = response { throw e }
        return response
    }

    /// release macOS's read-only mount → probe → mount read/write when clean.
    private func connect(_ id: String) async {
        guard let disk = cards.first(where: { $0.id == id })?.disk else { return }
        update(id) { $0.busy = .connecting; $0.errorText = nil; $0.userUnmounted = false }
        do {
            // macOS may have (re)mounted its own read-only copy, so always try to release it first.
            _ = try? await call(.releaseNative(device: disk.deviceNode))
            guard case .health(var health) = try await call(.probe(device: disk.deviceNode)) else { return }
            if health == .inUse {
                // Another driver (macOS's own, or Paragon's) grabbed the disk before us: release it and look again.
                _ = try? await call(.releaseNative(device: disk.deviceNode))
                if case .health(let again) = try await call(.probe(device: disk.deviceNode)) { health = again }
            }
            update(id) { $0.health = health }
            if !health.canMountReadWrite {
                let name = cards.first(where: { $0.id == id })?.disk.label ?? "NTFS"
                Notifier.shared.post(id: "attention-\(id)", title: S.notifyAttentionTitle(name), body: S.warning(for: health))
            }
            if health.canMountReadWrite,
               case .mounted(let mp) = try await call(.mount(device: disk.deviceNode, label: disk.label)) {
                update(id) { $0.mountPoint = mp }
                diskAccessDenied = false
                diskAccessConfirmed = true
                UserDefaults.standard.set(true, forKey: "diskAccessConfirmed")
                refreshUsage(id)
            }
        } catch {
            if (error as? MountError) == .diskAccessDenied { diskAccessDenied = true }
            update(id) { $0.errorText = S.message(for: error) }
        }
        update(id) { $0.busy = nil }
    }

    // MARK: actions

    /// Quick-formats the disk as NTFS, then reconnects it. Returns an error message, or nil on success.
    func erase(_ id: String, label: String) async -> String? {
        guard let disk = cards.first(where: { $0.id == id })?.disk else { return S.message(for: MountError.invalidDevice) }
        update(id) { $0.busy = .erasing; $0.errorText = nil; $0.mountPoint = nil; $0.userUnmounted = false }
        smoothers[id] = nil; detectors[id] = nil; activeSince[id] = nil
        var failure: String?
        do { _ = try await call(.erase(device: disk.deviceNode, label: label)) }
        catch { failure = S.message(for: error) }
        // The label we hold came from DiskArbitration before the format; use the new one for the card and mount point.
        let newLabel = failure == nil ? ntfsLabel(label) : disk.label
        update(id) {
            $0.disk = NTFSDisk(id: disk.id, label: newLabel, sizeBytes: disk.sizeBytes, deviceNode: disk.deviceNode)
            $0.busy = nil; $0.used = 0
        }
        await connect(id)
        return failure
    }

    func mount(_ id: String) { Task { await connect(id) } }

    func unmount(_ id: String) {
        guard let disk = cards.first(where: { $0.id == id })?.disk else { return }
        update(id) { $0.busy = .unmounting; $0.errorText = nil }
        Task {
            do {
                _ = try await call(.unmount(device: disk.deviceNode))
                update(id) { $0.mountPoint = nil; $0.userUnmounted = true; $0.isActive = false; $0.bytesPerSecond = 0 }
                smoothers[id] = nil; detectors[id] = nil; activeSince[id] = nil
            } catch {
                update(id) { $0.errorText = S.message(for: error) }
            }
            update(id) { $0.busy = nil }
        }
    }

    func retry(_ id: String) { Task { await connect(id) } }

    func repair(_ id: String) {
        guard let disk = cards.first(where: { $0.id == id })?.disk else { return }
        update(id) { $0.busy = .connecting; $0.errorText = nil }
        Task {
            do { _ = try await call(.repair(device: disk.deviceNode)) }
            catch { update(id) { $0.errorText = S.message(for: error); $0.busy = nil }; return }
            await connect(id)
        }
    }

    func open(_ id: String) {
        guard let mp = cards.first(where: { $0.id == id })?.mountPoint else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: mp))
    }

    func eject(_ id: String) {
        guard let disk = cards.first(where: { $0.id == id })?.disk else { return }
        update(id) { $0.busy = .ejecting; $0.errorText = nil }
        Task {
            do {
                if cards.first(where: { $0.id == id })?.mountPoint != nil { _ = try await call(.unmount(device: disk.deviceNode)) }
                await Self.ejectPhysical(wholeDisk(of: disk.id))
                cards.removeAll { $0.id == id }
            } catch {
                update(id) { $0.errorText = S.message(for: error); $0.busy = nil }
            }
        }
    }

    private static func ejectPhysical(_ whole: String) async {
        _ = try? await SystemProcessRunner().run("/usr/sbin/diskutil", ["eject", "/dev/\(whole)"])
    }

    func enableHelper() {
        do { try client.register() } catch { /* status below tells the story */ }
        refreshHelper()
        if helperStatus == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    func handleSetupAction(_ id: String) {
        switch id {
        case "helper": enableHelper()
        case "diskAccess":
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(url) }
        default: break
        }
    }

    // MARK: periodic

    private func wholeDisk(of bsd: String) -> String {
        bsd.firstMatch(of: /disk[0-9]+/).map { String($0.0) } ?? bsd
    }

    private func refreshHelper() { helperStatus = client.status }
    private func refreshEnvironment() { problems = NTFSCore.problems(in: inspectEnvironmentLive()); refreshHelper() }

    private func refreshUsage(_ id: String) {
        guard let mp = cards.first(where: { $0.id == id })?.mountPoint,
              let v = try? URL(fileURLWithPath: mp).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = v.volumeTotalCapacity, let free = v.volumeAvailableCapacity else { return }
        update(id) { $0.used = UInt64(max(0, total - free)) }
    }

    private static func isMountPoint(_ path: String) -> Bool {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return false }
        let mountedOn = withUnsafePointer(to: &info.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return mountedOn == path
    }

    private var tickCount = 0
    private func tick() {
        tickCount += 1
        if tickCount % 5 == 0 { refreshEnvironment() }
        let now = Date()
        // A volume unmounted from outside the app (Finder, Terminal) must not keep showing as connected.
        for card in cards where card.busy == nil {
            if let mp = card.mountPoint, !Self.isMountPoint(mp) {
                update(card.id) { $0.mountPoint = nil; $0.userUnmounted = true; $0.isActive = false; $0.bytesPerSecond = 0 }
                // Tell the helper to forget the old mount point, otherwise the next mount gets a " 2" suffix.
                let node = card.disk.deviceNode
                Task { _ = try? await client.send(.diskGone(device: node)) }
            }
        }
        for card in cards where card.mountPoint != nil {
            refreshUsage(card.id)
            guard let total = counters.totalBytes(for: wholeDisk(of: card.id)) else { continue }
            var smoother = smoothers[card.id] ?? ThroughputSmoother()
            let bps = smoother.add(totalBytes: total, at: now)
            smoothers[card.id] = smoother
            var detector = detectors[card.id] ?? ActivityDetector()
            let active = detector.update(bytesPerSecond: bps, at: now)
            detectors[card.id] = detector
            update(card.id) { $0.bytesPerSecond = bps; $0.isActive = active }
            // Tell the user when a real transfer (at least 10 s) has finished.
            if active, activeSince[card.id] == nil { activeSince[card.id] = now }
            if !active, let since = activeSince.removeValue(forKey: card.id), now.timeIntervalSince(since) >= 10 {
                let name = card.disk.label ?? "NTFS"
                Notifier.shared.post(id: "transfer-\(card.id)", title: S.notifyTransferTitle(name), body: S.notifyTransferBody(name))
            }
        }
    }
}
