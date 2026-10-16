//
//  IPv4.swift
//  tvRemoteDemo
//

import Foundation

/// An IPv4 address and netmask, both in host byte order.
nonisolated struct IPv4Subnet: Sendable, Equatable {
    var address: UInt32
    var netmask: UInt32
}

nonisolated enum IPv4 {
    static func parse(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let octet = UInt8(part) else { return nil }
            value = (value << 8) | UInt32(octet)
        }
        return value
    }

    static func string(_ value: UInt32) -> String {
        [24, 16, 8, 0].map { String((value >> UInt32($0)) & 0xFF) }.joined(separator: ".")
    }

    /// True for private (RFC 1918) and link-local addresses. Discovery never talks to anything else.
    static func isPrivateOrLinkLocal(_ text: String) -> Bool {
        guard let value = parse(text) else { return false }
        let first = value >> 24
        let second = (value >> 16) & 0xFF
        switch (first, second) {
        case (10, _), (192, 168), (169, 254):
            return true
        case (172, 16...31):
            return true
        default:
            return false
        }
    }
}

/// Lists the hosts to probe on the local subnet.
nonisolated enum SubnetHosts {
    /// Hosts of the subnet except our own address. Subnets larger than a /24 (for example a /16)
    /// are limited to the /24 around our own address, so a scan stays short.
    static func hosts(in subnet: IPv4Subnet) -> [String] {
        let prefix = subnet.netmask.nonzeroBitCount
        guard prefix < 31 else { return [] }

        let effectiveMask: UInt32 = prefix < 24 ? 0xFFFF_FF00 : subnet.netmask
        let network = subnet.address & effectiveMask
        let broadcast = network | ~effectiveMask

        return ((network + 1)..<broadcast)
            .filter { $0 != subnet.address }
            .map(IPv4.string)
    }
}
