import Foundation
import NTFSCore
import NTFSShared
import ServiceManagement

enum HelperStatus: Equatable { case notRegistered, requiresApproval, enabled }

enum HelperClientError: Error { case unreachable(String), badReply }

final class HelperClient: @unchecked Sendable {
    private let service = SMAppService.daemon(plistName: HelperConstants.daemonPlistName)

    var status: HelperStatus {
        switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .notRegistered
        }
    }

    func register() throws { try service.register() }

    func send(_ request: HelperRequest) async throws -> HelperResponse {
        let payload = try JSONEncoder().encode(request)
        let connection = NSXPCConnection(machServiceName: HelperConstants.machService, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: NTFSHelperXPC.self)
        connection.setCodeSigningRequirement(HelperConstants.helperRequirement)
        connection.resume()
        defer { connection.invalidate() }

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                if once.first() { continuation.resume(throwing: HelperClientError.unreachable("\(error)")) }
            } as? NTFSHelperXPC
            guard let proxy else {
                if once.first() { continuation.resume(throwing: HelperClientError.badReply) }
                return
            }
            proxy.send(payload) { reply in
                if once.first() { continuation.resume(returning: reply) }
            }
        }
        guard let response = try? JSONDecoder().decode(HelperResponse.self, from: data) else { throw HelperClientError.badReply }
        return response
    }
}

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func first() -> Bool { lock.withLock { defer { done = true }; return !done } }
}
