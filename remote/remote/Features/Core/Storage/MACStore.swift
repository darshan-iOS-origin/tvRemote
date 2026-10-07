//
//  MACStore.swift
//  tvRemoteDemo
//

import Foundation

/// Where a TV's MAC addresses are kept so it can be woken while it is off. A MAC address is a stable
/// hardware identifier, so it lives in the Keychain like a pairing token, and is never logged.
nonisolated protocol TVMACStoring: Sendable {
    func macs(for host: String, platform: TVPlatform) -> [MACAddress]
    func save(_ macs: [MACAddress], for host: String, platform: TVPlatform)
    func remove(for host: String, platform: TVPlatform)
}

/// One Keychain entry per platform and TV address, holding up to two addresses (Wi-Fi and wired)
/// separated by a comma.
nonisolated struct KeychainMACStore: TVMACStoring {
    private let store = KeychainTokenStore(service: "com.iOS.tvRemoteDemo.tvmac")

    func macs(for host: String, platform: TVPlatform) -> [MACAddress] {
        guard let stored = store.token(for: host, platform: platform) else { return [] }
        return WakeOnLAN.decode(stored)
    }

    func save(_ macs: [MACAddress], for host: String, platform: TVPlatform) {
        guard !macs.isEmpty else { return }
        store.save(WakeOnLAN.encode(Array(macs.prefix(2))), for: host, platform: platform)
    }

    func remove(for host: String, platform: TVPlatform) {
        store.remove(for: host, platform: platform)
    }
}
