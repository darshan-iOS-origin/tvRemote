//
//  UnicastSSDPTransport.swift
//  tvRemoteDemo
//
//  SSDP without multicast. The usual SSDP search is sent to the multicast address 239.255.255.250, which
//  iOS only allows with Apple's multicast networking entitlement (UDPSSDPTransport.swift). A search sent to
//  one host at a time is ordinary unicast UDP and needs no entitlement. So this sends the same M-SEARCH
//  to every address of the local subnet, and the TVs answer it the way they answer the multicast one
//  (a UPnP device must answer an M-SEARCH sent to its own address; Samsung, LG, Sony and Vizio TVs do so as
//  far as is known: UNVERIFIED on a real iPhone).
//
//  Only the phone's own subnet is searched (a /24 at most), and only private addresses are answered
//  to by the caller. The packets are sent twice, one second apart, because UDP can lose some.
//

import Foundation

nonisolated struct UnicastSSDPTransport: SSDPTransport {
    private let subnetProvider: LocalSubnetProviding

    init(subnetProvider: LocalSubnetProviding = InterfaceSubnetProvider()) {
        self.subnetProvider = subnetProvider
    }

    func search(searchTargets: [String], window: TimeInterval) -> AsyncThrowingStream<SSDPDatagram, Error> {
        AsyncThrowingStream<SSDPDatagram, Error> { continuation in
            guard let subnet = subnetProvider.currentSubnet() else {
                continuation.finish()
                return
            }
            let hosts = SubnetHosts.hosts(in: subnet)
            let stop = StopFlag()
            continuation.onTermination = { _ in stop.set() }

            ThreadManager.backgroundQueue.async {
                Self.run(hosts: hosts, targets: searchTargets, window: window, stop: stop) { datagram in
                    continuation.yield(datagram)
                }
                continuation.finish()
            }
        }
    }

    private static func run(
        hosts: [String],
        targets: [String],
        window: TimeInterval,
        stop: StopFlag,
        onDatagram: (SSDPDatagram) -> Void
    ) {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }

        // Wake up every 250 ms so a cancelled search stops promptly.
        var readTimeout = timeval(tv_sec: 0, tv_usec: 250_000)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.size))

        sendRound(hosts: hosts, targets: targets, on: descriptor, stop: stop)

        let deadline = Date().addingTimeInterval(window)
        let resendAt = Date().addingTimeInterval(1)
        var didResend = false
        var buffer = [UInt8](repeating: 0, count: 4096)

        while !stop.isSet, Date() < deadline {
            if !didResend, Date() >= resendAt {
                didResend = true
                sendRound(hosts: hosts, targets: targets, on: descriptor, stop: stop)
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

    /// One M-SEARCH per host and target. A host that cannot be reached is simply skipped.
    private static func sendRound(hosts: [String], targets: [String], on descriptor: Int32, stop: StopFlag) {
        for host in hosts {
            if stop.isSet { return }
            var destination = sockaddr_in()
            destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            destination.sin_family = sa_family_t(AF_INET)
            destination.sin_port = UInt16(1900).bigEndian
            destination.sin_addr.s_addr = inet_addr(host)

            for target in targets {
                let request = Data(searchRequest(host: host, target: target).utf8)
                _ = request.withUnsafeBytes { bytes in
                    withUnsafePointer(to: &destination) { pointer in
                        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                            sendto(descriptor, bytes.baseAddress, bytes.count, 0, address,
                                   socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
            }
        }
    }

    private static func searchRequest(host: String, target: String) -> String {
        [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(host):1900",
            "MAN: \"ssdp:discover\"",
            "MX: 2",
            "ST: \(target)",
            "",
            ""
        ].joined(separator: "\r\n")
    }
}

/// Runs several SSDP transports at once and streams every answer. One that fails (the multicast one, on an
/// iPhone without the entitlement) does not stop the others, so a scan always gets the unicast answers.
nonisolated struct CombinedSSDPTransport: SSDPTransport {
    private let transports: [SSDPTransport]

    init(transports: [SSDPTransport] = [UDPSSDPTransport(), UnicastSSDPTransport()]) {
        self.transports = transports
    }

    func search(searchTargets: [String], window: TimeInterval) -> AsyncThrowingStream<SSDPDatagram, Error> {
        let transports = self.transports
        return AsyncThrowingStream<SSDPDatagram, Error> { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for transport in transports {
                        group.addTask {
                            do {
                                for try await datagram in transport.search(searchTargets: searchTargets, window: window) {
                                    continuation.yield(datagram)
                                }
                            } catch {
                                LoggerManager.debug("An SSDP transport ended with an error: \(error)", category: "Discovery")
                            }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
