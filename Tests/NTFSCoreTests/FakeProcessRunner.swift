import Foundation
import Synchronization
@testable import NTFSCore

/// Returns queued results in order (or a default) and records every call.
final class FakeProcessRunner: ProcessRunning, Sendable {
    struct Call: Equatable { let executable: String; let arguments: [String] }
    private struct State { var queue: [ProcessResult]; var calls: [Call] = [] }

    private let state: Mutex<State>
    private let fallback: ProcessResult

    init(results: [ProcessResult] = [], fallback: ProcessResult = ProcessResult(status: 0)) {
        self.state = Mutex(State(queue: results))
        self.fallback = fallback
    }

    var calls: [Call] { state.withLock { $0.calls } }

    func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult {
        state.withLock { s in
            s.calls.append(Call(executable: executable, arguments: arguments))
            return s.queue.isEmpty ? fallback : s.queue.removeFirst()
        }
    }
}
