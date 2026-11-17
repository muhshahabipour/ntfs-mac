import Foundation
import NTFSCore
import NTFSShared

/// Root launch daemon: accepts only connections from our own signed app and runs mount commands.
final class HelperDelegate: NSObject, NSXPCListenerDelegate, NTFSHelperXPC, @unchecked Sendable {
    private let service = HelperService(engine: MountEngine())

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(HelperConstants.clientRequirement)
        connection.exportedInterface = NSXPCInterface(with: NTFSHelperXPC.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func send(_ request: Data, reply: @escaping @Sendable (Data) -> Void) {
        let service = self.service
        Task { reply(await service.handle(request)) }
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machService)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
