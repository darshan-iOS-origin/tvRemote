//
//  ManualTVProbe.swift
//  tvRemoteDemo
//
//  Checks a TV at an address the user typed, for when a scan cannot find it: the Android TV
//  emulator (README, "Testing with the Android TV emulator"), or a TV on another subnet. It only
//  looks at one address, and only a local one (`LocalTrustPolicy`; CLAUDE.md, local network only).
//
//  Today it checks for an Android / Google TV: port 6467 is the pairing port and 6466 the control
//  port, both from the AndroidTVRemoteControl README and the protocol wiki. Roku, Samsung and LG
//  can be added the same way.
//

import Foundation

nonisolated struct ManualTVProbe: Sendable {
    enum Failure: Error, Sendable, Equatable {
        /// The address is not a private or link-local IPv4 address.
        case notLocalAddress
        /// Neither Android TV port accepted a connection.
        case nothingAnswered
    }

    static let androidPairingPort: UInt16 = 6467
    static let androidControlPort: UInt16 = 6466

    private let prober: PortProbing
    private let timeout: TimeInterval

    init(prober: PortProbing = NWPortProber(), timeout: TimeInterval = 3) {
        self.prober = prober
        self.timeout = timeout
    }

    /// An Android / Google TV at `host`, or a `Failure`. The ports are tried one after the other.
    func androidTV(at host: String, name: String = "Android TV Emulator") async throws -> TVDevice {
        let address = host.trimmingCharacters(in: .whitespaces)
        guard LocalTrustPolicy.shouldTrust(host: address) else {
            throw Failure.notLocalAddress
        }

        var open: Set<UInt16> = []
        for port in [Self.androidPairingPort, Self.androidControlPort] {
            if await prober.isOpen(host: address, port: port, timeout: timeout) {
                open.insert(port)
            }
        }
        guard !open.isEmpty else {
            throw Failure.nothingAnswered
        }

        return TVDevice(
            name: name,
            brand: .other,
            platform: .androidTV,
            host: address,
            port: Int(Self.androidControlPort),
            sources: [.portProbe],
            openControlPorts: open
        )
    }
}
