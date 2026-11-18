import Foundation

/// Only whole disks and partitions of the form /dev/diskN or /dev/diskNsM. Nothing else may reach a tool.
public func isValidDiskDevice(_ path: String) -> Bool {
    path.wholeMatch(of: /\/dev\/disk[0-9]+(s[0-9]+)?/) != nil
}

public enum HelperRequest: Codable, Equatable, Sendable {
    case probe(device: String)
    case mount(device: String, label: String?)
    case repair(device: String)
    case unmount(device: String)
    case diskGone(device: String)
    case releaseNative(device: String)
    /// Quick-format a partition as NTFS. Destroys its contents.
    case erase(device: String, label: String)

    var device: String {
        switch self {
        case .probe(let d), .repair(let d), .unmount(let d), .diskGone(let d), .releaseNative(let d): d
        case .mount(let d, _), .erase(let d, _): d
        }
    }
}

public enum HelperResponse: Codable, Equatable, Sendable {
    case health(VolumeHealth)
    case mounted(mountPoint: String)
    case done
    case failure(MountError)
}

/// Transport-independent request handler. The XPC layer only moves bytes in and out of this.
public actor HelperService {
    private let engine: MountEngine
    public init(engine: MountEngine) { self.engine = engine }

    public func handle(_ data: Data) async -> Data {
        let response: HelperResponse
        if let request = try? JSONDecoder().decode(HelperRequest.self, from: data) {
            response = await handle(request)
        } else {
            response = .failure(.failed("bad request"))
        }
        return (try? JSONEncoder().encode(response)) ?? Data()
    }

    public func handle(_ request: HelperRequest) async -> HelperResponse {
        guard isValidDiskDevice(request.device) else { return .failure(.invalidDevice) }
        let node = request.device
        let id = String(node.dropFirst("/dev/".count))

        do {
            switch request {
            case .probe:
                return .health(try await engine.probe(NTFSDisk(id: id, label: nil, sizeBytes: 0, deviceNode: node)))
            case .mount(_, let label):
                return .mounted(mountPoint: try await engine.mountReadWrite(NTFSDisk(id: id, label: label, sizeBytes: 0, deviceNode: node)))
            case .repair:
                try await engine.repair(NTFSDisk(id: id, label: nil, sizeBytes: 0, deviceNode: node))
                return .done
            case .unmount:
                try await engine.unmount(NTFSDisk(id: id, label: nil, sizeBytes: 0, deviceNode: node))
                return .done
            case .releaseNative:
                try await engine.releaseNativeMount(NTFSDisk(id: id, label: nil, sizeBytes: 0, deviceNode: node))
                return .done
            case .erase(_, let label):
                try await engine.erase(NTFSDisk(id: id, label: nil, sizeBytes: 0, deviceNode: node), label: label)
                return .done
            case .diskGone:
                await engine.diskDisappeared(id: id)
                return .done
            }
        } catch let e as MountError {
            return .failure(e)
        } catch {
            return .failure(.failed("\(error)"))
        }
    }
}
