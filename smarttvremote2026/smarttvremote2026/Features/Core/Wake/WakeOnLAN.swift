//
//  WakeOnLAN.swift
//  tvRemoteDemo
//
//  Wake-on-LAN: a "magic packet" is 6 bytes of 0xFF followed by the TV's MAC address 16 times (102
//  bytes), sent as UDP. A TV in standby with network wake switched on turns on when it sees its own
//  MAC. The format is the same in SmartCastKit's WakeOnLAN.swift (MIT, copyright 2026 Yuri Barreira);
//  only the format is used, no code.
//

import Foundation

/// A MAC address. It is never logged (CLAUDE.md): it is a stable hardware identifier.
nonisolated struct MACAddress: Sendable, Equatable {
    let bytes: [UInt8]

    /// Reads `AA:BB:CC:DD:EE:FF`, `AA-BB-CC-DD-EE-FF` or `AABBCCDDEEFF`. Nil for anything else, and for
    /// the all-zero and all-FF addresses, which no TV has.
    init?(_ text: String) {
        let digits = text.filter { $0 != ":" && $0 != "-" }
        guard digits.count == 12 else { return nil }
        var parsed: [UInt8] = []
        var index = digits.startIndex
        for _ in 0..<6 {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else { return nil }
            parsed.append(byte)
            index = next
        }
        guard parsed.contains(where: { $0 != 0 }), parsed.contains(where: { $0 != 0xFF }) else { return nil }
        bytes = parsed
    }

    /// `AA:BB:CC:DD:EE:FF`.
    var text: String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Every MAC address written as text inside `string`, in order, without repeats. Used to read the
    /// addresses out of a TV's reply or certificate without depending on where the TV puts them.
    static func all(in string: String) -> [MACAddress] {
        guard let regex = try? NSRegularExpression(pattern: "(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}") else {
            return []
        }
        let range = NSRange(string.startIndex..., in: string)
        var found: [MACAddress] = []
        for match in regex.matches(in: string, range: range) {
            guard let matchRange = Range(match.range, in: string),
                  let address = MACAddress(String(string[matchRange])),
                  !found.contains(address) else { continue }
            found.append(address)
        }
        return found
    }
}

nonisolated enum WakeOnLAN {
    private static let ports: [UInt16] = [9, 7]
    private static let repeats = 3
    private static let repeatDelay: useconds_t = 300_000

    /// The 102-byte magic packet for one MAC address.
    static func packet(for mac: MACAddress) -> Data {
        var bytes = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            bytes.append(contentsOf: mac.bytes)
        }
        return Data(bytes)
    }

    /// The saved MAC list as it is kept in the Keychain: addresses separated by commas.
    static func encode(_ macs: [MACAddress]) -> String {
        macs.map(\.text).joined(separator: ",")
    }

    static func decode(_ stored: String) -> [MACAddress] {
        stored.split(separator: ",").compactMap { MACAddress(String($0)) }
    }

    /// Sends the packet for every address to the subnet's broadcast address and to the TV's own address.
    /// Only a private address is ever a target, the same limit as the rest of the app. Throws
    /// `TVError.wakeFailed` if nothing could be sent (on iOS the broadcast can be refused without
    /// Apple's multicast networking entitlement, and the TV's own address answers only if the TV
    /// still holds it). Runs on a background queue because it uses a blocking socket.
    static func send(to macs: [MACAddress], host: String, subnet: IPv4Subnet?) async throws {
        var targets: [String] = []
        if LocalTrustPolicy.shouldTrust(host: host) {
            targets.append(host)
        }
        if let subnet {
            let broadcast = IPv4.string(subnet.address | ~subnet.netmask)
            if IPv4.isPrivateOrLinkLocal(broadcast) {
                targets.append(broadcast)
            }
        }
        guard !macs.isEmpty, !targets.isEmpty else {
            throw TVError.wakeFailed
        }
        let packets = macs.map(packet(for:))

        let sentAny = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            ThreadManager.backgroundQueue.async {
                continuation.resume(returning: sendAll(packets, to: targets))
            }
        }
        guard sentAny else {
            throw TVError.wakeFailed
        }
        LoggerManager.debug("Wake packet sent", category: "WakeOnLAN")
    }

    /// True if at least one send went out.
    private static func sendAll(_ packets: [Data], to targets: [String]) -> Bool {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var allowBroadcast: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_BROADCAST, &allowBroadcast, socklen_t(MemoryLayout<Int32>.size))

        var sentAny = false
        for round in 0..<repeats {
            if round > 0 {
                usleep(repeatDelay)
            }
            for target in targets {
                for port in ports {
                    var destination = sockaddr_in()
                    destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                    destination.sin_family = sa_family_t(AF_INET)
                    destination.sin_port = port.bigEndian
                    destination.sin_addr.s_addr = inet_addr(target)
                    for packet in packets {
                        let sent = packet.withUnsafeBytes { bytes in
                            withUnsafePointer(to: &destination) { pointer in
                                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                                    sendto(descriptor, bytes.baseAddress, bytes.count, 0, address,
                                           socklen_t(MemoryLayout<sockaddr_in>.size))
                                }
                            }
                        }
                        if sent == packet.count {
                            sentAny = true
                        }
                    }
                }
            }
        }
        return sentAny
    }
}
