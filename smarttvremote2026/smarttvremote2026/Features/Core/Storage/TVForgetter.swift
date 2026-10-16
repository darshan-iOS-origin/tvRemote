//
//  TVForgetter.swift
//  tvRemoteDemo
//

import Foundation

/// Forgets a TV completely: its saved entry, its favorites, and the pairing token kept for it in the
/// Keychain (a Samsung token or an LG client key). An Android / Google TV's pairing lives on the TV, so
/// it cannot be cleared from here: remove this phone in the TV's own settings if you want that.
nonisolated struct TVForgetter: Sendable {
    var devices: DeviceStoring = UserDefaultsDeviceStore()
    var favorites: FavoriteStoring = UserDefaultsFavoriteStore()
    var tokens: TVTokenStoring = KeychainTokenStore()
    var macs: TVMACStoring = KeychainMACStore()

    /// A TV got a new address from the router: its favorites and pairing token follow it.
    func moveData(from oldHost: String, to newHost: String) {
        guard oldHost != newHost else { return }
        favorites.move(from: oldHost, to: newHost)
        for platform in [TVPlatform.tizen, .webOS, .smartCast, .bravia, .fireTV] {
            if let token = tokens.token(for: oldHost, platform: platform) {
                tokens.save(token, for: newHost, platform: platform)
                tokens.remove(for: oldHost, platform: platform)
            }
        }
        // The MAC address is the TV's own, so it does not change with its network address.
        for platform in Self.controlPlatforms {
            let saved = macs.macs(for: oldHost, platform: platform)
            if !saved.isEmpty {
                macs.save(saved, for: newHost, platform: platform)
                macs.remove(for: oldHost, platform: platform)
            }
        }
    }

    func forget(host: String) {
        devices.remove(host: host)
        favorites.clear(for: host)
        for platform in [TVPlatform.tizen, .webOS, .smartCast, .bravia, .fireTV] {
            tokens.remove(for: host, platform: platform)
        }
        for platform in Self.controlPlatforms {
            macs.remove(for: host, platform: platform)
        }
    }

    private static let controlPlatforms: [TVPlatform] = [.roku, .androidTV, .tizen, .webOS, .smartCast, .bravia, .fireTV]
}
