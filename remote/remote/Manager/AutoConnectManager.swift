import UIKit

/// Connects to a saved TV by itself, so the remote works as soon as the tabs open: the default TV first
/// (History > Set As Default), otherwise the TV that was connected last. It runs when the tabs open and
/// whenever the app returns to the foreground without a connected TV. A small toast at the bottom shows
/// what is happening ("Connecting…", then the result); a TV that is off or unreachable is simply skipped.
/// Every kind of TV is tried the same way: connect with what is already saved. A TV that shows a pairing
/// code and has never been paired (or lost its pairing) then goes through the normal pairing flow
/// (`TVConnector`: the code dialog), so the user types the code once and later launches connect silently.
@MainActor
final class AutoConnectManager {

    static let shared = AutoConnectManager()

    private var attempt: Task<Void, Never>?
    /// Runs the pairing flow for a TV that needs a code. Kept here so it lives while its dialog is up.
    private var connector: TVConnector?
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
            await self?.run()
            self?.attempt = nil
        }
    }

    private func run() async {
        guard await AppServices.connection.activeDevice == nil, let saved = Self.preferredTV() else { return }
        let device = saved.device
        let kind = AppServices.pairing.kind(for: device)
        if case .unavailable = kind { return }

        ToastView.show("Connecting to \(device.name)…", showsSpinner: true)
        guard await TVReachability.isOnline(host: device.host, platform: device.platform), !Task.isCancelled else {
            LoggerManager.info("Auto connect: \(device.name) is not answering", category: "Connect")
            ToastView.show("Couldn't reach \(device.name)")
            return
        }
        do {
            try await AppServices.connection.connect(to: device)
            LoggerManager.info("Auto connected to \(device.name) (\(device.host))", category: "Connect")
            ToastView.show("Connected to \(device.name)")
        } catch let error as TVError {
            if error == .notPaired, case .code = kind {
                ToastView.hide()
                pair(device)
            } else {
                LoggerManager.warning("Auto connect to \(device.name) failed: \(error)", category: "Connect")
                ToastView.show("Couldn't connect to \(device.name)")
            }
        } catch {
            LoggerManager.warning("Auto connect to \(device.name) failed: \(error)", category: "Connect")
            ToastView.show("Couldn't connect to \(device.name)")
        }
    }

    /// Hands a TV that needs a pairing code to the normal pairing flow, over whatever screen is showing.
    private func pair(_ device: TVDevice) {
        guard let presenter = UIViewController.topMost else { return }
        let connector = TVConnector(presenter: presenter)
        connector.onConnected = { ToastView.show("Connected to \(device.name)") }
        self.connector = connector
        connector.connect(to: device)
    }

    /// The default TV, otherwise the one connected most recently.
    private static func preferredTV() -> SavedTV? {
        let saved = UserDefaultsDeviceStore().load()
        return saved.first { $0.isDefault == true }
            ?? saved.max { ($0.lastConnected ?? .distantPast) < ($1.lastConnected ?? .distantPast) }
    }
}
