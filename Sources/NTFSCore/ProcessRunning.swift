import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public init(status: Int32, stdout: String = "", stderr: String = "") {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Runs an executable with an argv array. Never goes through a shell.
public protocol ProcessRunning: Sendable {
    func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "ntfs.process.io", attributes: .concurrent)
            let group = DispatchGroup()
            nonisolated(unsafe) var outData = Data(), errData = Data()
            group.enter(); queue.async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            group.enter(); queue.async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            process.terminationHandler = { p in
                group.notify(queue: queue) {
                    continuation.resume(returning: ProcessResult(
                        status: p.terminationStatus,
                        stdout: String(decoding: outData, as: UTF8.self),
                        stderr: String(decoding: errData, as: UTF8.self)))
                }
            }
            do { try process.run() } catch {
                try? out.fileHandleForWriting.close()
                try? err.fileHandleForWriting.close()
                continuation.resume(throwing: error)
            }
        }
    }
}
