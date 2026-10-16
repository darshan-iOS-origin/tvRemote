//
//  MirrorGuide.swift
//  tvRemoteDemo
//

import Foundation

/// The words on the Mirror screen. Three ways to mirror:
/// - Web Browser tab: the broadcast extension serves a viewer page; any browser on the Wi-Fi opens its address.
/// - AirPlay (Samsung, LG, Sony, Roku, Vizio): Apple does not let an app start AirPlay mirroring by code, so
///   the app only helps the user start the iPhone's own mirroring.
/// - Broadcast (Android TV / Google TV, which have no AirPlay): the user starts a screen broadcast, the app's
///   broadcast extension streams the screen, and the TV plays it over Google Cast (`MirrorController`).
nonisolated enum MirrorGuide {
    static let screenTitle = "Screen Mirroring"
    static let smartTVTab = "Smart TV"
    static let webTab = "Web Browser"

    static let wifiCard = "Ensure all devices are connected to the same Wi-Fi network."
    /// Smart TV tab, on an Android TV / Google TV.
    static let broadcastCard = "Tap the 'record' button below and then tap 'Start Broadcasting'."
    /// Smart TV tab, on a TV that mirrors with AirPlay.
    static let airPlayCard = "Tap 'Open AirPlay' below and choose your TV from the list."
    /// Smart TV tab, with no TV connected.
    static let connectTVCard = "Connect a TV first, then come back here to start mirroring."
    static let webCard = "Open browser on the other device (TV, desktop, etc.) and enter this URL:"
    static let noWiFiAddress = "Connect to Wi-Fi to get an address"

    static let qualityTitle = "Quality"
    static let copyTitle = "Copy"
    static let copiedTitle = "Copied"
    static let shareTitle = "Share"

    static let openAirPlayTitle = "Open AirPlay"
    static let startBroadcastTitle = "Start Broadcasting"
    static let stopBroadcastTitle = "Stop Broadcasting"
    static let connectingTitle = "Connecting to TV…"

    /// Under the button, whatever the tab.
    static let privacyNote = "Mirroring shows everything on your screen, including notifications. "
        + "Turn on Do Not Disturb first, and stop when you are done."

    /// Shown when no TV is connected.
    static let defaultNote = "Connect a TV first. Android TV and Google TV mirror through this app; "
        + "other TVs mirror with AirPlay."

    /// True for TVs this app can't mirror to at all: no AirPlay and no Google Cast.
    static func cannotMirror(_ platform: TVPlatform) -> Bool {
        platform == .fireTV
    }

    /// True for TVs that mirror through the app's broadcast and Google Cast instead of AirPlay.
    static func usesBroadcastMirroring(_ platform: TVPlatform) -> Bool {
        platform == .androidTV
    }

    /// Where to switch AirPlay on, and which TVs have it. All from memory, UNVERIFIED.
    /// TODO: confirm each line against the brand's own support page.
    static func note(for platform: TVPlatform) -> String {
        switch platform {
        case .tizen:
            return "Samsung TVs from 2018 have AirPlay 2. Make sure it is on in the TV's settings "
                + "(General, then Apple AirPlay Settings)."
        case .webOS:
            return "LG TVs from 2019 have AirPlay 2. Make sure it is on in the TV's settings "
                + "(look for AirPlay in the Home Dashboard or the settings)."
        case .roku:
            return "Many Roku players and TVs have AirPlay (Roku OS 9.4 or newer). Make sure it is on "
                + "(Settings, then Apple AirPlay and HomeKit)."
        case .androidTV:
            return "Android TV and Google TV mirror through Google Cast. Keep the iPhone on the same Wi-Fi as the TV. "
                + "The TV shows the screen a few seconds late, so it suits photos and videos more than games."
        case .fireTV:
            return "A Fire TV has no AirPlay, and this app can't mirror to one yet. An AirPlay receiver app from "
                + "the Amazon Appstore may let the iPhone mirror to it (UNVERIFIED)."
        case .bravia:
            return "Many Sony Bravia TVs from 2019 or later have AirPlay 2. Make sure it is on in the TV's settings "
                + "(look for Apple AirPlay and HomeKit)."
        case .smartCast:
            return "Many Vizio SmartCast TVs from 2018 or later have AirPlay 2. Make sure it is on in the TV's "
                + "settings (look for Apple AirPlay)."
        case .unknown:
            return "Mirroring works only on a TV that supports AirPlay."
        }
    }
}
