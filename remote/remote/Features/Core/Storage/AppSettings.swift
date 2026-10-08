//
//  AppSettings.swift
//  tvRemoteDemo
//

import Foundation

/// Which remote layout every TV gets. **Auto** is the original behaviour: the Google TV style on an
/// Android / Google TV, the standard one on the rest.
nonisolated enum RemoteLayoutPreference: String, Sendable, CaseIterable {
    case auto
    case standard
    case googleTV

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .standard: return "Standard"
        case .googleTV: return "Google TV style"
        }
    }

    var detail: String {
        switch self {
        case .auto: return "Google TV style on an Android / Google TV, standard on the others."
        case .standard: return "The same remote for every TV."
        case .googleTV: return "Round pad and TV keys for every TV. Keys a TV does not have are hidden on it."
        }
    }
}

/// App-wide choices, kept on this phone in `UserDefaults`. Nothing in here is secret.
nonisolated enum AppSettings {
    private static let layoutKey = "remoteLayoutPreference"
    private static let premiumKey = "isPremium"

    /// Whether the user has the PRO plan. The Settings tab hides the PRO banner when it is true.
    /// Nothing sets it yet: purchases are not built.
    static var isPremium: Bool {
        get { UserDefaults.standard.bool(forKey: premiumKey) }
        set { UserDefaults.standard.set(newValue, forKey: premiumKey) }
    }

    static var remoteLayout: RemoteLayoutPreference {
        get {
            UserDefaults.standard.string(forKey: layoutKey).flatMap(RemoteLayoutPreference.init(rawValue:)) ?? .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: layoutKey)
        }
    }
}
