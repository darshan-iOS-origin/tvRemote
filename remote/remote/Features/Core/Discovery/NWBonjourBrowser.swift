//
//  NWBonjourBrowser.swift
//  tvRemoteDemo
//

import Foundation
import Network

/// Browses Bonjour service types with `NWBrowser` and resolves each result to an IPv4 address.
/// Bonjour does not need the multicast entitlement. Every type must be listed under
/// `NSBonjourServices` in Info.plist, or `NWBrowser` fails.
///
/// UNVERIFIED on a real device: `NWBrowser` results carry no IP address, so each result is
/// resolved by opening a short TCP connection to the service and reading the remote endpoint from
/// the connection's path. Check that this yields an IPv4 address on a real TV.
nonisolated struct NWBonjourBrowser: BonjourBrowsing {
    private static let resolveTimeout: TimeInterval = 3

    func browse(serviceTypes: [String]) -> AsyncStream<BonjourService> {
        AsyncStream<BonjourService> { continuation in
            let queue = DispatchQueue(label: "tvremote.discovery.bonjour")
            let browsers = serviceTypes.map {
                NWBrowser(for: .bonjour(type: $0, domain: nil), using: .tcp)
            }

            for browser in browsers {
                browser.browseResultsChangedHandler = { _, changes in
                    for change in changes {
                        if case .added(let result) = change {
                            Self.resolve(result, queue: queue) { continuation.yield($0) }
                        }
                    }
                }
                browser.start(queue: queue)
            }

            continuation.onTermination = { _ in
                browsers.forEach { $0.cancel() }
            }
        }
    }

    private static func resolve(
        _ result: NWBrowser.Result,
        queue: DispatchQueue,
        completion: @escaping @Sendable (BonjourService) -> Void
    ) {
        guard case let .service(name, type, _, _) = result.endpoint else { return }

        let txt: [String: String]
        if case let .bonjour(record) = result.metadata {
            txt = record.dictionary
        } else {
            txt = [:]
        }

        let parameters = NWParameters.tcp
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(to: result.endpoint, using: parameters)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if case let .hostPort(host, port)? = connection.currentPath?.remoteEndpoint,
                   case let .ipv4(address) = host {
                    let text = address.rawValue.map(String.init).joined(separator: ".")
                    completion(BonjourService(name: name, serviceType: type, host: text, port: Int(port.rawValue), txt: txt))
                }
                connection.cancel()
            case .failed:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + resolveTimeout) { connection.cancel() }
    }
}
