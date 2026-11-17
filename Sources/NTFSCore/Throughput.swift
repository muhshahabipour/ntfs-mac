import Foundation
import IOKit

/// Disk activity above this counts as a copy in progress.
public let activityThresholdBytesPerSecond = 1_000_000.0

/// Exponential moving average of bytes/second from a monotonically increasing byte counter.
public struct ThroughputSmoother: Sendable {
    private var last: (bytes: UInt64, time: Date)?
    private var smoothed = 0.0
    private let alpha: Double

    public init(alpha: Double = 0.5) { self.alpha = alpha }

    public mutating func add(totalBytes: UInt64, at time: Date) -> Double {
        defer { last = (totalBytes, time) }
        guard let last else { return 0 }
        guard totalBytes >= last.bytes else { smoothed = 0; return 0 }   // counters reset (disk re-appeared)
        let dt = time.timeIntervalSince(last.time)
        guard dt > 0 else { return smoothed }
        let instant = Double(totalBytes - last.bytes) / dt
        smoothed = alpha * instant + (1 - alpha) * smoothed
        return smoothed
    }
}

/// Turns a speed into "is a copy running", with a 2 s hold-off so the UI doesn't flicker.
public struct ActivityDetector: Sendable {
    private var lastActive: Date?
    private let holdOff: TimeInterval

    public init(holdOff: TimeInterval = 2) { self.holdOff = holdOff }

    public mutating func update(bytesPerSecond: Double, at time: Date) -> Bool {
        if bytesPerSecond >= activityThresholdBytesPerSecond { lastActive = time }
        guard let lastActive else { return false }
        return time.timeIntervalSince(lastActive) <= holdOff
    }
}

public protocol IOCounterSource: Sendable {
    /// Total bytes read + written by the physical device behind `bsdName`, or nil if unknown.
    func totalBytes(for bsdName: String) -> UInt64?
}

/// Reads `IOBlockStorageDriver` statistics. Verified manually (Task 10), not unit-tested.
public struct IOKitCounterSource: IOCounterSource {
    public init() {}

    public func totalBytes(for bsdName: String) -> UInt64? {
        guard let matching = IOBSDNameMatching(kIOMainPortDefault, 0, bsdName) else { return nil }
        let media = IOServiceGetMatchingService(kIOMainPortDefault, matching)   // consumes `matching`
        guard media != 0 else { return nil }
        var current = media                                                      // owned by us, released below

        while true {
            if IOObjectConformsTo(current, "IOBlockStorageDriver") != 0 {
                defer { IOObjectRelease(current) }
                guard let stats = IORegistryEntryCreateCFProperty(current, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? [String: Any] else { return nil }
                let read = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                let written = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
                return read &+ written
            }
            var parent: io_registry_entry_t = 0
            let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            IOObjectRelease(current)
            guard kr == KERN_SUCCESS else { return nil }
            current = parent
        }
    }
}
