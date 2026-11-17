import Testing
@testable import NTFSCore

@Suite struct CardStateTests {
    private let tb: UInt64 = 1_000_000_000_000

    @Test func cleanMountedIdleIsReady() {
        #expect(cardState(health: .clean, mounted: true, bytesPerSecond: 0, used: tb, total: 2 * tb) == .ready(usedFraction: 0.5))
    }

    @Test func cleanButNotYetMountedIsMounting() {
        #expect(cardState(health: .clean, mounted: false, bytesPerSecond: 0, used: tb, total: 2 * tb) == .mounting)
    }

    @Test func dirtyNeedsAttention() {
        #expect(cardState(health: .dirty, mounted: false, bytesPerSecond: 0, used: tb, total: 2 * tb)
                == .needsAttention(.dirty, usedFraction: 0.5))
    }

    @Test func hibernatedNeedsAttentionAndIsNotRepairable() {
        let s = cardState(health: .hibernated, mounted: false, bytesPerSecond: 0, used: 0, total: tb)
        #expect(s == .needsAttention(.hibernated, usedFraction: 0))
        #expect(!VolumeHealth.hibernated.isRepairable)
    }

    @Test func inUseByAnotherDriverNeedsAttention() {
        #expect(cardState(health: .inUse, mounted: false, bytesPerSecond: 0, used: 0, total: tb)
                == .needsAttention(.inUse, usedFraction: 0))
    }

    @Test func mountedWithTrafficIsCopying() {
        #expect(cardState(health: .clean, mounted: true, bytesPerSecond: 185_000_000, used: tb, total: 2 * tb)
                == .copying(bytesPerSecond: 185_000_000, usedFraction: 0.5))
    }

    @Test func fractionEdgeCases() {
        #expect(usedFraction(used: 0, total: 0) == 0)             // no NaN
        #expect(usedFraction(used: 5, total: 0) == 0)
        #expect(usedFraction(used: 3 * tb, total: 2 * tb) == 1)   // clamped
        #expect(usedFraction(used: 0, total: 2 * tb) == 0)
        #expect(usedFraction(used: 2 * tb, total: 2 * tb) == 1)
    }
}
