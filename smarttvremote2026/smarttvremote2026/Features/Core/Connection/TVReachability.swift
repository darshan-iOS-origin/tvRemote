import Foundation
import Network

/// Whether a saved TV answers on the network right now: a plain TCP connect to one of the ports its
/// platform listens on. Nothing is sent, so it needs no pairing.
nonisolated enum TVReachability {

    static func isOnline(host: String, platform: TVPlatform, timeout: TimeInterval = 1.5) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            for port in ports(for: platform) {
                group.addTask { await canConnect(host: host, port: port, timeout: timeout) }
            }
            for await online in group where online {
                group.cancelAll()
                return true
            }
            return false
        }
    }

    private static func ports(for platform: TVPlatform) -> [UInt16] {
        switch platform {
        case .roku: return [8060]
        case .tizen: return [8002, 8001]
        case .webOS: return [3000, 3001]
        case .androidTV: return [6466, 8009]
        case .smartCast: return [7345, 9000]
        case .bravia: return [80]
        case .fireTV: return [8009]
        case .unknown: return [8060, 8002, 3001, 6466, 7345, 80]
        }
    }

    private static func canConnect(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let gate = Gate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                @Sendable func finish(_ result: Bool) {
                    guard gate.claim() else { return }
                    connection.cancel()
                    continuation.resume(returning: result)
                }
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready: finish(true)
                    case .failed, .cancelled: finish(false)
                    default: break
                    }
                }
                connection.start(queue: .global(qos: .utility))
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { finish(false) }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    /// Lets the first of ready / failed / timeout win, so the continuation resumes once.
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }
}
