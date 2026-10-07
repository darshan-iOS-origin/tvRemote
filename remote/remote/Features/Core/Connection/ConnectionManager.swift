//
//  ConnectionManager.swift
//  tvRemoteDemo
//

import Foundation

/// Holds the TV the remote is controlling. Screens send keys through it and never touch a brand's
/// controller (CLAUDE.md). It picks the controller from the TV's platform.
///
/// Built so far: Roku, Android / Google TV, Samsung Tizen, LG webOS and Vizio SmartCast. Any other platform reports
/// `TVError.unsupported`. Reconnecting when the app returns to the foreground is not built yet.
actor ConnectionManager {
    private let makeController: @Sendable (TVDevice) -> TVController?
    private let macStore: TVMACStoring
    private let subnetProvider: LocalSubnetProviding
    private var controller: TVController?
    private(set) var activeDevice: TVDevice?

    init(
        controllerFactory: @escaping @Sendable (TVDevice) -> TVController? = ConnectionManager.defaultController,
        macStore: TVMACStoring = KeychainMACStore(),
        subnetProvider: LocalSubnetProviding = InterfaceSubnetProvider()
    ) {
        self.makeController = controllerFactory
        self.macStore = macStore
        self.subnetProvider = subnetProvider
    }

    /// The controller for a TV's platform, or nil when its control is not built yet.
    static func defaultController(for device: TVDevice) -> TVController? {
        switch device.platform {
        case .roku:
            return RokuController(host: device.host)
        case .androidTV:
            return AndroidTVController(host: device.host)
        case .tizen:
            return SamsungTizenController(host: device.host)
        case .webOS:
            return LGWebOSController(host: device.host)
        case .smartCast:
            return VizioController(host: device.host)
        case .bravia:
            return BraviaController(host: device.host)
        case .fireTV:
            return FireTVController(host: device.host)
        case .unknown:
            return nil
        }
    }

    /// The platforms with every feature: keys, text, apps, channels, voice.
    private static let fullControl: [TVPlatform] = [.roku, .androidTV, .tizen, .webOS]

    /// Whether text can be typed on a TV of this platform. The same four platforms as keys.
    static func canType(_ platform: TVPlatform) -> Bool {
        fullControl.contains(platform) || platform == .bravia
    }

    /// Whether the app has a way to switch channels on a TV of this platform. It only works on a TV that
    /// has a tuner (a Chromecast with Google TV has none).
    static func canOpenChannels(_ platform: TVPlatform) -> Bool {
        fullControl.contains(platform)
    }

    /// Whether media can be cast to a TV of this platform: Google Cast on Android / Google TV, the
    /// "Play on Roku" channel on a Roku, and DLNA on Samsung and LG.
    static func canCast(_ platform: TVPlatform) -> Bool {
        canControl(platform) && platform != .fireTV
    }

    /// Whether voice can be used on a TV of this platform. Android / Google TV streams the audio to the TV's
    /// own assistant. The others use speech recognised on the phone (see `ConnectionManager+Voice`).
    static func canUseVoice(_ platform: TVPlatform) -> Bool {
        fullControl.contains(platform)
    }

    /// Whether a TV of this platform has a key for this. The remote hides keys a TV does not have. It asks the
    /// same tables the controllers send with, so the two cannot disagree. Roku launches Live TV as an app, so
    /// it counts too. A TV we cannot control hides nothing.
    static func supports(_ key: KeyCommand, on platform: TVPlatform) -> Bool {
        switch platform {
        case .roku: return key == .liveTV || RokuController.keyCode(for: key) != nil
        case .androidTV: return AndroidTVRemoteMessages.supports(key)
        case .tizen: return SamsungTizenController.remoteKey(for: key) != nil
        case .webOS: return LGWebOSController.route(for: key) != nil
        case .smartCast: return VizioController.code(for: key) != nil
        case .bravia: return BraviaController.supports(key)
        case .fireTV: return FireTVController.supports(key)
        case .unknown: return true
        }
    }

    /// Whether the TV has a cursor the phone can move, like LG's Magic Remote. LG webOS only.
    static func canUsePointer(_ platform: TVPlatform) -> Bool {
        platform == .webOS
    }

    /// Whether apps can be listed and opened on a TV of this platform. The same four platforms.
    static func canLaunchApps(_ platform: TVPlatform) -> Bool {
        fullControl.contains(platform) || platform == .bravia || platform == .fireTV
    }

    /// Whether keys can be sent to a TV of this platform yet.
    static func canControl(_ platform: TVPlatform) -> Bool {
        switch platform {
        case .roku, .androidTV, .tizen, .webOS, .smartCast, .bravia, .fireTV: return true
        case .unknown: return false
        }
    }

    /// Makes `device` the active TV, dropping the previous one. Does nothing if it is already the
    /// active TV, so the remote can reuse the connection the connect screen opened. A controller
    /// reopens a connection that died by itself when a key is sent. Throws a `TVError`.
    func connect(to device: TVDevice) async throws {
        if controller != nil, activeDevice?.host == device.host {
            return
        }
        await disconnect()
        guard let newController = makeController(device) else {
            throw TVError.unsupported(device.platform)
        }
        try await newController.connect()
        controller = newController
        activeDevice = device
        // While the TV is on and answering, learn its MAC address so it can be woken when it is off.
        let addresses = await newController.hardwareAddresses()
        macStore.save(addresses, for: device.host, platform: device.platform)
    }

    /// Whether a MAC address is saved for this TV, so Wake-on-LAN can be tried.
    func canWake(_ device: TVDevice) -> Bool {
        // A Fire TV is woken by an HTTP call and needs no saved MAC address.
        device.platform == .fireTV || !macStore.macs(for: device.host, platform: device.platform).isEmpty
    }

    /// Sends a Wake-on-LAN packet to a TV that is off. It does not wait for the TV to come up: the
    /// caller tries `connect(to:)` again. Throws `TVError.wakeUnavailable` if no MAC address is saved
    /// for the TV, and `TVError.wakeFailed` if nothing could be sent.
    func wake(_ device: TVDevice) async throws {
        if device.platform == .fireTV {
            try await FireTVController.wake(host: device.host)
            return
        }
        let addresses = macStore.macs(for: device.host, platform: device.platform)
        guard !addresses.isEmpty else {
            throw TVError.wakeUnavailable
        }
        try await WakeOnLAN.send(to: addresses, host: device.host, subnet: subnetProvider.currentSubnet())
    }

    /// Reopens the connection to the active TV, for example when the app returns from the background.
    /// Throws `TVError.notConnected` if no TV is active. Throws a `TVError`.
    func reconnect() async throws {
        guard let controller else {
            throw TVError.notConnected
        }
        try await controller.connect()
    }

    /// Sends a key to the active TV. Throws a `TVError`.
    func send(_ key: KeyCommand) async throws {
        guard let controller else {
            throw TVError.notConnected
        }
        try await controller.send(key)
    }

    /// Types into the text field focused on the active TV. Throws a `TVError`.
    func send(_ text: TextCommand) async throws {
        guard let controller else {
            throw TVError.notConnected
        }
        try await controller.send(text)
    }

    /// Moves the active TV's cursor, clicks or scrolls. Throws a `TVError`.
    func send(_ pointer: PointerCommand) async throws {
        guard let controller else {
            throw TVError.notConnected
        }
        try await controller.send(pointer)
    }

    /// Switches the active TV to a channel by number. Throws a `TVError`.
    func openChannel(_ number: String) async throws {
        guard let controller else {
            throw TVError.notConnected
        }
        try await controller.openChannel(number)
    }

    /// Starts casting to the active TV. Throws a `TVError`.
    func startCasting() async throws -> any CastSession {
        guard let controller else {
            throw TVError.notConnected
        }
        return try await controller.startCasting()
    }

    /// Starts a voice session on the active TV. Throws a `TVError`.
    func startVoice() async throws -> any VoiceSession {
        guard let controller else {
            throw TVError.notConnected
        }
        return try await controller.startVoice()
    }

    /// Forces how text is typed on the active TV, for the debug switch on the keyboard sheet.
    func setTextInputMethod(_ method: TextInputMethod) async {
        await controller?.setTextInputMethod(method)
    }

    /// The apps to show for the active TV. Throws a `TVError`.
    func apps() async throws -> [TVApp] {
        guard let controller else {
            throw TVError.notConnected
        }
        return try await controller.apps()
    }

    /// Opens an app on the active TV. Throws a `TVError`.
    func launch(_ app: TVApp) async throws {
        guard let controller else {
            throw TVError.notConnected
        }
        try await controller.launch(app)
    }

    func disconnect() async {
        await controller?.disconnect()
        controller = nil
        activeDevice = nil
    }

    /// Disconnects only if `device` is still the active TV. A screen that is closing uses this so it
    /// cannot drop a connection that another screen has opened in the meantime.
    func disconnect(from device: TVDevice) async {
        guard activeDevice?.host == device.host else { return }
        await disconnect()
    }
}
