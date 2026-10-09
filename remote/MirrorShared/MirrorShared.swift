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
            updatedAt: Date(timeIntervalSince1970: defaults.double(forKey: Key.updatedAt))
        )
    }

    static func write(state: State, port: UInt16 = 0, token: String = "") {
        guard let defaults else { return }
        defaults.set(state.rawValue, forKey: Key.state)
        defaults.set(Int(port), forKey: Key.port)
        defaults.set(token, forKey: Key.token)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.updatedAt)
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
