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
    private static let firstLaunchFlowKey = "hasCompletedFirstLaunchFlow"
    private static let mirrorQualityKey = "mirrorQuality"

    /// Whether the user has the PRO plan: the last answer from RevenueCat, kept so the next launch is right
    /// before the network answers. Only `SubscriptionManager` writes it; read it through
    /// `SubscriptionManager.shared.isPremium`, and listen to `SubscriptionManager.didChangeNotification`.
    /// True once a first-time user has gone all the way from the splash to the tabs (permissions,
    /// onboarding, scan, subscription screens). Until then every launch repeats the first-time flow.
    static var hasCompletedFirstLaunchFlow: Bool {
        get { UserDefaults.standard.bool(forKey: firstLaunchFlowKey) }
        set { UserDefaults.standard.set(newValue, forKey: firstLaunchFlowKey) }
    }

    static var isPremium: Bool {
        get { UserDefaults.standard.bool(forKey: premiumKey) }
        set { UserDefaults.standard.set(newValue, forKey: premiumKey) }
    }

    /// The picture quality chosen on the Screen Mirroring screen (480p until the user picks another). A
    /// Premium quality that was chosen while Premium is 480p again once Premium has ended.
    static var mirrorQuality: MirrorShared.Quality {
        get {
            let saved = UserDefaults.standard.string(forKey: mirrorQualityKey).flatMap(MirrorShared.Quality.init(rawValue:)) ?? .p480
            return saved.isPremium && !isPremium ? .p480 : saved
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: mirrorQualityKey)
        }
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
