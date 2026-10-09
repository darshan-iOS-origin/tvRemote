//
//  MirrorShared.swift
//  remote + MirrorBroadcast
//
//  What the app and its broadcast extension both need to know. The two are separate processes: the
//  extension captures the screen and serves it as a live stream, the app tells the TV to play it. They
//  talk through the App Group's UserDefaults (where the stream is) and Darwin notifications (when it
//  starts and stops). This file is compiled into both targets.
//
//  Nothing private is stored: a port number, a random token that guards the stream, a state, and a time.
//

import Foundation
import Security

nonisolated enum MirrorShared {
    static let appGroupID = "group.com.tvremote.universal.smartcontro"
    /// The broadcast extension. The app's picker asks for it by this ID.
    static let extensionBundleID = "com.tvremote.universal.smartcontro.MirrorBroadcast"

    static let readyNotification = "com.tvremote.universal.smartcontro.mirror.ready"
    static let stoppedNotification = "com.tvremote.universal.smartcontro.mirror.stopped"

    /// The extension refreshes this often while it runs. A "ready" state older than `staleAfter` means the
    /// extension was killed without saying so.
    static let heartbeatInterval: TimeInterval = 2
    static let staleAfter: TimeInterval = 6

    static let playlistName = "live.m3u8"
    static let initSegmentName = "init.mp4"

    /// The address part after the phone's IP and port, for example `/9f2c…/live.m3u8`.
    static func playlistPath(token: String) -> String {
        "/\(token)/\(playlistName)"
    }

    // MARK: - Choices made in the app

    /// Who watches: a TV that is told to play the stream over Google Cast, or any browser on the Wi-Fi that
    /// opens the viewer page.
    enum Mode: String {
        case cast
        case web
    }

    /// The picture size and quality. The extension has little memory, so 1080p is the one to watch.
    enum Quality: String, CaseIterable {
        case p480
        case p720
        case p1080

        var title: String {
            switch self {
            case .p480: return "480p"
            case .p720: return "720p(HD)"
            case .p1080: return "1080p(Full HD)"
            }
        }

        /// 720p and 1080p carry the crown in the design.
        var isPremium: Bool {
            self != .p480
        }

        var width: Int {
            switch self {
            case .p480: return 854
            case .p720: return 1280
            case .p1080: return 1920
            }
        }

        var height: Int {
            switch self {
            case .p480: return 480
            case .p720: return 720
            case .p1080: return 1080
            }
        }

        var bitRate: Int {
            switch self {
            case .p480: return 1_200_000
            case .p720: return 3_500_000
            case .p1080: return 6_000_000
            }
        }
    }

    /// The address of the viewer page is on this port when it is free, so the app can show it before the
    /// broadcast starts. Otherwise the extension picks another and reports it.
    static let preferredWebPort: UInt16 = 8099

    struct Config {
        var mode: Mode = .cast
        var quality: Quality = .p480
        /// The short code in the viewer page's address (web mode).
        var webCode = ""
    }

    private static let codeAlphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")

    /// A short random code for the viewer page's address, without look-alike letters (no i, l, o, 0, 1).
    static func makeWebCode() -> String {
        var bytes = [UInt8](repeating: 0, count: 6)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<6).map { _ in UInt8.random(in: 0...255) }
        }
        return String(bytes.map { codeAlphabet[Int($0) % codeAlphabet.count] })
    }

    enum State: String {
        /// The broadcast started; the stream is not playable yet.
        case starting
        /// The stream has enough segments for the TV to start.
        case ready
        case stopped
        case failed
    }

    /// The stream as the extension last described it.
    struct Status {
        var state: State
        var port: UInt16
        var token: String
        var updatedAt: Date
        var mode: Mode = .cast

        /// True while the extension says it is serving and has said so recently.
        var isLive: Bool {
            state == .ready && port != 0 && !token.isEmpty && Date().timeIntervalSince(updatedAt) < staleAfter
        }
    }

    private enum Key {
        static let state = "mirror.state"
        static let port = "mirror.port"
        static let token = "mirror.token"
        static let updatedAt = "mirror.updatedAt"
        static let statusMode = "mirror.statusMode"
        static let mode = "mirror.config.mode"
        static let quality = "mirror.config.quality"
        static let webCode = "mirror.config.webCode"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func read() -> Status? {
        guard let defaults, let raw = defaults.string(forKey: Key.state), let state = State(rawValue: raw) else {
            return nil
        }
        return Status(
            state: state,
            port: UInt16(clamping: defaults.integer(forKey: Key.port)),
            token: defaults.string(forKey: Key.token) ?? "",
            updatedAt: Date(timeIntervalSince1970: defaults.double(forKey: Key.updatedAt)),
            mode: defaults.string(forKey: Key.statusMode).flatMap(Mode.init(rawValue:)) ?? .cast
        )
    }

    static func write(state: State, port: UInt16 = 0, token: String = "", mode: Mode = .cast) {
        guard let defaults else { return }
        defaults.set(mode.rawValue, forKey: Key.statusMode)
        defaults.set(state.rawValue, forKey: Key.state)
        defaults.set(Int(port), forKey: Key.port)
        defaults.set(token, forKey: Key.token)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.updatedAt)
    }

    /// What the app asks for. The app writes it just before the broadcast picker opens; the extension reads it
    /// when the broadcast starts. A broadcast started from Control Center gets the last choice made.
    static func readConfig() -> Config {
        guard let defaults else { return Config() }
        return Config(
            mode: defaults.string(forKey: Key.mode).flatMap(Mode.init(rawValue:)) ?? .cast,
            quality: defaults.string(forKey: Key.quality).flatMap(Quality.init(rawValue:)) ?? .p480,
            webCode: defaults.string(forKey: Key.webCode) ?? ""
        )
    }

    static func writeConfig(_ config: Config) {
        guard let defaults else { return }
        defaults.set(config.mode.rawValue, forKey: Key.mode)
        defaults.set(config.quality.rawValue, forKey: Key.quality)
        defaults.set(config.webCode, forKey: Key.webCode)
    }

    static func touch() {
        defaults?.set(Date().timeIntervalSince1970, forKey: Key.updatedAt)
    }

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

/// Listens for Darwin notifications by name, for as long as it is kept. The handler runs on whatever
/// thread the system uses; hop to the main actor inside it.
nonisolated final class DarwinNotificationObserver: @unchecked Sendable {
    private let handler: @Sendable (String) -> Void

    init(names: [String], handler: @escaping @Sendable (String) -> Void) {
        self.handler = handler
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        for name in names {
            CFNotificationCenterAddObserver(
                center,
                observer,
                { _, observer, name, _, _ in
                    guard let observer, let name else { return }
                    let me = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue()
                    me.handler(name.rawValue as String)
                },
                name as CFString,
                nil,
                .deliverImmediately
            )
        }
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
