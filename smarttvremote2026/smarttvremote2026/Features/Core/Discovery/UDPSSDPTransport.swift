//
//  UDPSSDPTransport.swift
//  tvRemoteDemo
//

import Foundation

/// SSDP over a plain BSD UDP socket. A socket is used instead of `NWConnection` because search
/// responses are unicast replies from many different hosts, which a connected UDP flow would drop.
///
/// UNVERIFIED on a real device: iOS needs Apple's multicast networking entitlement to send to
/// 239.255.255.250. Without it `sendto` is expected to fail (probably EHOSTUNREACH), which this
/// transport reports as `ssdpUnavailable` so the service falls back to the subnet probe.
nonisolated final class UDPSSDPTransport: SSDPTransport {
    private static let multicastAddress = "239.255.255.250"
    private static let port: UInt16 = 1900

    func search(searchTargets: [String], window: TimeInterval) -> AsyncThrowingStream<SSDPDatagram, Error> {
        AsyncThrowingStream<SSDPDatagram, Error> { continuation in
            let stop = StopFlag()
            continuation.onTermination = { _ in stop.set() }

            ThreadManager.backgroundQueue.async {
                do {
                    try Self.run(searchTargets: searchTargets, window: window, stop: stop) { datagram in
                        continuation.yield(datagram)
                    }
                    continuation.finish()
                } catch {
                    if case TVDiscoveryError.ssdpUnavailable = error {
                        LoggerManager.warning("SSDP unavailable; subnet probe may be used", category: "Discovery")
                    } else {
                        LoggerManager.debug("SSDP search failed: \(error)", category: "Discovery")
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func run(
        searchTargets: [String],
        window: TimeInterval,
        stop: StopFlag,
        onDatagram: (SSDPDatagram) -> Void
    ) throws {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { throw TVDiscoveryError.ssdpUnavailable }
        defer { close(descriptor) }

        // Wake up every 250 ms so a cancelled search stops promptly.
        var readTimeout = timeval(tv_sec: 0, tv_usec: 250_000)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.size))
        var timeToLive: UInt8 = 2
        setsockopt(descriptor, IPPROTO_IP, IP_MULTICAST_TTL, &timeToLive, socklen_t(MemoryLayout<UInt8>.size))

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = port.bigEndian
        destination.sin_addr.s_addr = inet_addr(multicastAddress)

        let requests = searchTargets.map(searchRequest)
        try sendAll(requests, on: descriptor, to: &destination)

        let deadline = Date().addingTimeInterval(window)
        // UDP can lose a packet, so the search is sent a second time after one second.
        let resendAt = Date().addingTimeInterval(1)
        var didResend = false
        var buffer = [UInt8](repeating: 0, count: 4096)

        while !stop.isSet, Date() < deadline {
            if !didResend, Date() >= resendAt {
                didResend = true
                try sendAll(requests, on: descriptor, to: &destination)
            }

            var source = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = buffer.withUnsafeMutableBytes { raw in
                withUnsafeMutablePointer(to: &source) { sourcePointer in
                    sourcePointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                        recvfrom(descriptor, raw.baseAddress, raw.count, 0, address, &sourceLength)
                    }
                }
            }

            if count > 0 {
                let text = String(decoding: buffer[0..<count], as: UTF8.self)
                let host = IPv4.string(UInt32(bigEndian: source.sin_addr.s_addr))
                onDatagram(SSDPDatagram(text: text, sourceHost: host))
            } else if count < 0, errno != EAGAIN, errno != EWOULDBLOCK, errno != EINTR {
                break
            }
        }
    }

    private static func sendAll(_ requests: [Data], on descriptor: Int32, to destination: inout sockaddr_in) throws {
        for request in requests {
            let sent = request.withUnsafeBytes { bytes in
                withUnsafePointer(to: &destination) { destinationPointer in
                    destinationPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                        sendto(descriptor, bytes.baseAddress, bytes.count, 0, address,
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            if sent < 0 { throw TVDiscoveryError.ssdpUnavailable }
        }
    }

    private static func searchRequest(for target: String) -> Data {
        let lines = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastAddress):\(port)",
            "MAN: \"ssdp:discover\"",
            "MX: 2",
            "ST: \(target)",
            "",
            ""
        ]
        return Data(lines.joined(separator: "\r\n").utf8)
    }
}

/// A thread-safe "stop" signal shared between the stream and its socket loop.
nonisolated final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
