import Foundation

public enum CardState: Equatable, Sendable {
    case mounting
    case ready(usedFraction: Double)
    case needsAttention(VolumeHealth, usedFraction: Double)
    case copying(bytesPerSecond: Double, usedFraction: Double)
    case ejecting
    case unmounting
    /// Attached but deliberately not mounted (user unmounted it, or it was unmounted elsewhere).
    case unmounted
    case failed(String)
}

/// 0...1, never NaN: an unknown/zero total gives 0, overfull gives 1.
public func usedFraction(used: UInt64, total: UInt64) -> Double {
    guard total > 0 else { return 0 }
    return min(1, Double(used) / Double(total))
}

public func cardState(health: VolumeHealth, mounted: Bool, bytesPerSecond: Double,
                      used: UInt64, total: UInt64, userUnmounted: Bool = false) -> CardState {
    let fraction = usedFraction(used: used, total: total)
    if mounted {
        return bytesPerSecond >= activityThresholdBytesPerSecond
            ? .copying(bytesPerSecond: bytesPerSecond, usedFraction: fraction)
            : .ready(usedFraction: fraction)
    }
    if userUnmounted { return .unmounted }
    return health.canMountReadWrite ? .mounting : .needsAttention(health, usedFraction: fraction)
}
