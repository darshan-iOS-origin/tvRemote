//
//  AirPlayFinder.swift
//  tvRemoteDemo
//

import Foundation

/// Checks whether a TV advertises AirPlay on the local network, so the Mirror screen can say whether
/// the iPhone's own screen mirroring can reach it. It browses Bonjour `_airplay._tcp` with the same
/// browser discovery uses, which resolves each result to an IPv4 address, and looks for the TV's address.
/// Nothing is stored or sent anywhere.
///
/// UNVERIFIED on a real TV: that the AirPlay service answers on the same address as the control port.
/// A "no" is a hint, not proof that the TV lacks AirPlay.
nonisolated struct AirPlayFinder: Sendable {
    /// Must also be listed under `NSBonjourServices` in Info.plist.
    static let serviceType = "_airplay._tcp"

    private let browser: BonjourBrowsing
    private let window: TimeInterval

    init(browser: BonjourBrowsing = NWBonjourBrowser(), window: TimeInterval = 6) {
        self.browser = browser
        self.window = window
    }

    /// True if a device at `host` advertises AirPlay within the search window.
    func isAirPlayAvailable(at host: String) async -> Bool {
        let browser = browser
        let nanoseconds = UInt64(window * 1_000_000_000)
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await service in browser.browse(serviceTypes: [Self.serviceType]) where service.host == host {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: nanoseconds)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}
