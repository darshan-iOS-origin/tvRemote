//
//  InterfaceSubnetProvider.swift
//  tvRemoteDemo
//

import Foundation

/// Reads the Wi-Fi interface's IPv4 address and netmask.
/// `en0` is the Wi-Fi interface on iPhone. UNVERIFIED on a real device: check that the name is
/// right, and note that Personal Hotspot uses another interface.
nonisolated struct InterfaceSubnetProvider: LocalSubnetProviding {
    private let interfaceName = "en0"

    #if DEBUG
    /// The first private IPv4 address on any other interface, preferring `en*`. Debug builds only: the iOS
    /// Simulator uses the Mac's network, and a Mac on a wired network has no address on `en0`, so casting
    /// from the Simulator to the Android TV emulator needs an address to put in the media link.
    /// Release builds never use it. UNVERIFIED on a Mac.
    static func anyPrivateAddress() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var candidates: [(name: String, address: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            cursor = entry.pointee.ifa_next
            guard let address = entry.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  entry.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let text = IPv4.string(value)
            guard IPv4.isPrivateOrLinkLocal(text), !text.hasPrefix("169.254.") else { continue }
            candidates.append((String(cString: entry.pointee.ifa_name), text))
        }
        return (candidates.first { $0.name.hasPrefix("en") } ?? candidates.first)?.address
    }
    #endif

    func currentSubnet() -> IPv4Subnet? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            cursor = entry.pointee.ifa_next

            guard let address = entry.pointee.ifa_addr,
                  let netmask = entry.pointee.ifa_netmask,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  String(cString: entry.pointee.ifa_name) == interfaceName else { continue }

            let addressValue = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let netmaskValue = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            return IPv4Subnet(address: addressValue, netmask: netmaskValue)
        }
        return nil
    }
}
