import Foundation
import Testing
@testable import NTFSCore

@Suite struct ThroughputTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func constantRateConverges() {
        var s = ThroughputSmoother()
        var last = 0.0
        for i in 0...20 {
            last = s.add(totalBytes: UInt64(i) * 100_000_000, at: t0.addingTimeInterval(Double(i)))
        }
        #expect(abs(last - 100_000_000) < 5_000_000)
    }

    @Test func firstSampleIsZero() {
        var s = ThroughputSmoother()
        let r = s.add(totalBytes: 5_000_000, at: t0)
        #expect(r == 0)
    }

    @Test func counterGoingBackwardsYieldsZeroNotNegative() {
        var s = ThroughputSmoother()
        _ = s.add(totalBytes: 0, at: t0)
        _ = s.add(totalBytes: 900_000_000, at: t0 + 1)
        let r = s.add(totalBytes: 10, at: t0 + 2)     // disk re-appeared, counters reset
        #expect(r == 0)
        // and it recovers afterwards
        let recovered = s.add(totalBytes: 100_000_010, at: t0 + 3)
        #expect(recovered > 0)
    }

    @Test func activityHasAHoldOff() {
        var a = ActivityDetector()
        let busy = a.update(bytesPerSecond: 50_000_000, at: t0)
        let held = a.update(bytesPerSecond: 0, at: t0 + 1)      // still within 2 s hold-off
        let idle = a.update(bytesPerSecond: 0, at: t0 + 3)      // idle long enough
        #expect(busy)
        #expect(held)
        #expect(!idle)
    }

    @Test func tinyTrafficIsNotActivity() {
        var a = ActivityDetector()
        let active = a.update(bytesPerSecond: 200_000, at: t0)
        #expect(!active)
    }
}
