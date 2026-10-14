import UIKit

/// Connects to a saved TV by itself, so the remote works as soon as the tabs open: the default TV first
/// (History > Set As Default), otherwise the TV that was connected last. It runs when the tabs open and
/// whenever the app returns to the foreground without a connected TV, and it is silent: no loader and no
/// alert, and a TV that is off or unreachable is simply skipped. A TV that needs a pairing code is never
/// connected here (the user does that from the list); one that only asks for approval on the TV is.
@MainActor
final class AutoConnectManager {

    static let shared = AutoConnectManager()

    private var attempt: Task<Void, Never>?
    private var isObserving = false

    private init() {}

    /// Starts watching for the app coming back to the foreground and makes the first attempt. Safe to call again.
    func start() {
        if !isObserving {
            isObserving = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(appEnteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil
            )
        }
        connectIfNeeded()
    }

    @objc private func appEnteredForeground() {
        connectIfNeeded()
    }

    private func connectIfNeeded() {
        guard attempt == nil else { return }
        attempt = Task { [weak self] in
            await Self.run()
            self?.attempt = nil
        }
    }

    private static func run() async {
        guard await AppServices.connection.activeDevice == nil, let saved = preferredTV() else { return }
        let device = saved.device
        switch AppServices.pairing.kind(for: device) {
        case .none, .approveOnTV:
            break
        case .code, .unavailable:
            return
        }
        guard await TVReachability.isOnline(host: device.host, platform: device.platform), !Task.isCancelled else {
            LoggerManager.info("Auto connect: \(device.name) is not answering", category: "Connect")
            return
        }
        do {
            try await AppServices.connection.connect(to: device)
            LoggerManager.info("Auto connected to \(device.name) (\(device.host))", category: "Connect")
        } catch {
            LoggerManager.warning("Auto connect to \(device.name) failed: \(error)", category: "Connect")
        }
    }

    /// The default TV, otherwise the one connected most recently.
    private static func preferredTV() -> SavedTV? {
        let saved = UserDefaultsDeviceStore().load()
        return saved.first { $0.isDefault == true }
            ?? saved.max { ($0.lastConnected ?? .distantPast) < ($1.lastConnected ?? .distantPast) }
    }
}
