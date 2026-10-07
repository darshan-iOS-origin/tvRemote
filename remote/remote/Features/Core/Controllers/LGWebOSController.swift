//
//  LGWebOSController.swift
//  tvRemoteDemo
//
//  LG webOS. The first connection shows an Accept popup on the TV, with no code. The TV then hands
//  out a client key, which we keep in the Keychain so the next connection shows no popup. The
//  protocol and the button names are in LGWebOSSession.swift.
//

import Foundation

nonisolated struct LGWebOSController: TVController {
    let platform = TVPlatform.webOS

    private let host: String
    private let session: LGWebOSSession

    init(host: String, store: TVTokenStoring = KeychainTokenStore(), approvalTimeout: TimeInterval = ApprovalWait.defaultTimeout) {
        self.host = host
        self.session = LGWebOSSession(host: host, store: store, approvalTimeout: approvalTimeout)
    }

    func connect() async throws {
        try await session.open()
    }

    func send(_ key: KeyCommand) async throws {
        guard let route = Self.route(for: key) else {
            throw TVError.unsupportedKey(key)
        }
        switch route {
        case .button(let name):
            try await session.press(name)
        case .request(let uri):
            try await session.request(uri)
        case .input(let id):
            try await session.switchInput(id)
        case .launch(let id):
            try await session.launchApp(id: id)
        }
    }

    func send(_ text: TextCommand) async throws {
        switch text {
        case .insert(let string):
            guard !string.isEmpty else { return }
            try await session.insertText(string)
        case .backspace:
            try await session.deleteCharacters(count: 1)
        case .enter:
            try await session.sendEnterKey()
        }
    }

    /// The apps installed on the TV.
    func apps() async throws -> [TVApp] {
        try await session.listApps()
    }

    func openChannel(_ number: String) async throws {
        guard ChannelNumber.isValid(number) else {
            throw TVError.unsupportedCharacter
        }
        try await session.openChannel(number)
    }

    func launch(_ app: TVApp) async throws {
        try await session.launchApp(id: app.id)
    }

    /// Casts through the TV's DLNA renderer (DLNACastSession.swift). UNVERIFIED on a real TV: LG's
    /// renderer has no fixed address, so it is found with the UPnP search only.
    func startCasting() async throws -> any CastSession {
        let session = DLNACastSession(host: host)
        try await session.open()
        return session
    }

    func send(_ pointer: PointerCommand) async throws {
        switch pointer {
        case .move(let dx, let dy): try await session.movePointer(dx: dx, dy: dy)
        case .click: try await session.click()
        case .scroll(let dx, let dy): try await session.scroll(dx: dx, dy: dy)
        }
    }

    func hardwareAddresses() async -> [MACAddress] {
        await session.hardwareAddresses()
    }

    func disconnect() async {
        await session.close()
    }

    enum Route: Equatable {
        /// A button on the TV's pointer socket.
        case button(String)
        /// An SSAP request.
        case request(String)
        /// Open an app by id (`ssap://system.launcher/launch`).
        case launch(String)
        /// Switch to an input, by id such as `HDMI_2` (`ssap://tv/switchInput`, lgtv2's README).
        case input(String)
    }

    /// Button names are from lgtv2's README and PyWebOSTV's input commands. Power and play / pause
    /// have no button there, so they use the SSAP requests lgtv2 lists. UNVERIFIED: that
    /// `media.controls/play` toggles, so Play / Pause may only play.
    static func route(for key: KeyCommand) -> Route? {
        switch key {
        case .power: return .request("ssap://system/turnOff")
        case .volumeUp: return .button("VOLUMEUP")
        case .volumeDown: return .button("VOLUMEDOWN")
        case .mute: return .button("MUTE")
        case .channelUp: return .button("CHANNELUP")
        case .channelDown: return .button("CHANNELDOWN")
        case .up: return .button("UP")
        case .down: return .button("DOWN")
        case .left: return .button("LEFT")
        case .right: return .button("RIGHT")
        case .select: return .button("ENTER")
        case .back: return .button("BACK")
        case .home: return .button("HOME")
        case .menu: return .button("MENU")
        case .rewind: return .button("REWIND")
        case .playPause: return .request("ssap://media.controls/play")
        case .fastForward: return .button("FASTFORWARD")
        // webOS's live TV app id, from memory: UNVERIFIED.
        case .liveTV: return .launch("com.webos.app.livetv")
        case .hdmi1: return .input("HDMI_1")
        case .hdmi2: return .input("HDMI_2")
        case .hdmi3: return .input("HDMI_3")
        case .hdmi4: return .input("HDMI_4")
        // The Google TV layout's keys. No button name is confirmed for them on LG.
        case .input, .settings, .guide: return nil
        // Pointer-socket button names from lgtv2's README: PLAY PAUSE STOP INFO EXIT CC RED GREEN YELLOW BLUE.
        // It lists nothing for Next or Previous. UNVERIFIED on a real TV.
        case .play: return .button("PLAY")
        case .pause: return .button("PAUSE")
        case .stop: return .button("STOP")
        case .info: return .button("INFO")
        case .exit: return .button("EXIT")
        case .subtitles: return .button("CC")
        case .red: return .button("RED")
        case .green: return .button("GREEN")
        case .yellow: return .button("YELLOW")
        case .blue: return .button("BLUE")
        case .next, .previous: return nil
        // The pointer socket's digit buttons "0" to "9", listed in lgtv2's README. UNVERIFIED on a real TV.
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return .button(String(key.digitValue ?? 0))
        }
    }
}
