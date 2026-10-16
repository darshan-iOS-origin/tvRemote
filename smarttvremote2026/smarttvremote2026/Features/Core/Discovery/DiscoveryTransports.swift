//
//  DiscoveryTransports.swift
//  tvRemoteDemo
//
//  The network seams of TVDiscoveryService. Each one has a real implementation in this folder.
//

import Foundation

/// Failures that make a discovery source give up. `TVDiscoveryService` handles them itself
/// (for example by falling back to the subnet probe); they never reach the caller.
/// TODO: fold into `TVError` once that type exists.
nonisolated enum TVDiscoveryError: Error, Sendable, Equatable {
    case ssdpUnavailable
    case badResponse
}

/// One raw SSDP datagram and the IPv4 address it came from.
nonisolated struct SSDPDatagram: Sendable, Equatable {
    var text: String
    var sourceHost: String
}

nonisolated protocol SSDPTransport: Sendable {
    /// Sends an M-SEARCH for each target and streams the raw responses for `window` seconds.
    /// The stream throws `TVDiscoveryError.ssdpUnavailable` when multicast cannot be used.
    func search(searchTargets: [String], window: TimeInterval) -> AsyncThrowingStream<SSDPDatagram, Error>
}

nonisolated protocol HTTPDataFetching: Sendable {
    /// GET with a timeout. Throws for non-2xx responses.
    func data(from url: URL, timeout: TimeInterval) async throws -> Data
}

/// A Bonjour service whose IPv4 address has been resolved.
nonisolated struct BonjourService: Sendable, Equatable {
    var name: String
    var serviceType: String
    var host: String?
    var port: Int?
    /// TXT record entries advertised with the service.
    var txt: [String: String] = [:]
}

nonisolated protocol BonjourBrowsing: Sendable {
    func browse(serviceTypes: [String]) -> AsyncStream<BonjourService>
}

nonisolated protocol PortProbing: Sendable {
    func isOpen(host: String, port: UInt16, timeout: TimeInterval) async -> Bool
}

nonisolated protocol LocalSubnetProviding: Sendable {
    func currentSubnet() -> IPv4Subnet?
}

nonisolated struct TVDiscoveryConfiguration: Sendable {
    var ssdpWindow: TimeInterval = 3
    var fetchTimeout: TimeInterval = 3
    var probeTimeout: TimeInterval = 0.75
    /// Upper bound on simultaneous probe connections. Each one is a file descriptor, and iOS
    /// starts with a limit of 256 per process.
    var maxConcurrentProbes = 48
}
