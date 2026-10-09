//
//  MirrorGuide.swift
//  tvRemoteDemo
//

import Foundation

/// The words on the Mirror screen. The app does not capture the screen: Apple does not let an app start
/// AirPlay mirroring by code, so the app only helps the user start the iPhone's own mirroring.
nonisolated enum MirrorGuide {
    static let screenTitle = "Screen Mirroring"
    static let warning = "Turn on Do Not Disturb first, and stop mirroring when you are done."
    static let howToTitle = "How to Mirror Screen"
    static let stopHint = "To stop, open the same list and tap Stop Mirroring."
    static let openAirPlayTitle = "Open AirPlay"
    /// Shown when no TV is connected.
    static let defaultNote = "A Chromecast or Google TV has no AirPlay, and this app can't mirror to one yet. "
        + "Some Android TVs from other brands do have AirPlay."

    static let stepItems: [(title: String, detail: String)] = [
        ("Open Screen Mirroring", "Tap the AirPlay button below, or open Control Center and tap Screen Mirroring."),
        ("Choose Your TV", "Select your TV from the list."),
        ("Enter The Code", "If the TV shows a code, type it on the iPhone.")
    ]

    static let privacyNote = "Mirroring shows everything on your iPhone screen on the TV, including notifications "
        + "and anything private. Turn on Do Not Disturb first, and stop mirroring when you are done."

    static let steps = """
        1. Tap the AirPlay button below, or open Control Center and tap Screen Mirroring.
        2. Choose your TV in the list.
        3. If the TV shows a code, type it on the iPhone.

        To stop, open the same list and tap Stop Mirroring.
        """

    /// True for TVs that have no AirPlay at all, so mirroring to them can't work.
    static func cannotMirror(_ platform: TVPlatform) -> Bool {
        platform == .androidTV || platform == .fireTV
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
            return "A Chromecast or Google TV has no AirPlay, and this app can't mirror to one yet. "
                + "Some Android TVs from other brands do have AirPlay."
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
