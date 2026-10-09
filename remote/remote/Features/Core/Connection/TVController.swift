//
//  TVController.swift
//  tvRemoteDemo
//

import Foundation

/// What a brand's controller can do, in brand-neutral terms. One implementation per platform, one
/// file each. Screens never use one directly: they go through `ConnectionManager`.
///
nonisolated protocol TVController: Sendable {
    var platform: TVPlatform { get }

    /// Makes the TV ready for keys. Throws a `TVError`.
    func connect() async throws

    /// Sends one key, translated to the TV's own protocol. Throws a `TVError`.
    func send(_ key: KeyCommand) async throws

    /// Types into the text field that is focused on the TV. Throws a `TVError`.
    func send(_ text: TextCommand) async throws

    /// The apps the launcher shows: installed apps for Roku and LG, a fixed catalog for the others.
    func apps() async throws -> [TVApp]

    /// Forces how text is typed, for debug builds. Controllers with one way ignore it.
    func setTextInputMethod(_ method: TextInputMethod) async

    /// Switches the TV to a live channel by its number (for example `5` or `7.1`). Throws a `TVError`,
    /// `unsupportedChannels` for a TV with no way for this app to do it.
    func openChannel(_ number: String) async throws

    /// Starts casting: the TV plays photos, videos and music from web addresses. Throws a `TVError`,
    /// `unsupportedCasting` for a TV with no such feature this app can use.
    func startCasting() async throws -> any CastSession

    /// Starts a voice session: the phone's microphone audio goes to the TV's own assistant. Throws a
    /// `TVError`, `unsupportedVoice` for a TV with no such feature.
    func startVoice() async throws -> any VoiceSession

    /// Opens an app from `apps()` on the TV. Throws a `TVError`.
    func launch(_ app: TVApp) async throws

    /// Moves the TV's cursor, clicks or scrolls, like a Magic Remote. Throws a `TVError`,
    /// `unsupportedPointer` for a TV with no on-screen cursor this app can drive.
    func send(_ pointer: PointerCommand) async throws

    /// The TV's MAC addresses (Wi-Fi and wired) when it tells us, so it can be woken with Wake-on-LAN
    /// later. Empty when it does not. Never throws: a TV that cannot say is simply not wakeable.
    func hardwareAddresses() async -> [MACAddress]

    func disconnect() async
}

/// One casting session with a TV: it is told web addresses to play, and the TV fetches them itself.
nonisolated protocol CastSession: Sendable {
    /// Plays a photo, video or song from a web address on the TV. Throws a `TVError`.
    func play(url: URL, contentType: String, title: String) async throws
    /// Plays the live screen-mirroring stream (HLS) from a web address. Throws a `TVError`,
    /// `unsupportedCasting` for a session that can't play a live stream.
    func playLive(url: URL, title: String) async throws
    func pause() async throws
    func resume() async throws
    /// Stops what is playing but keeps the session.
    func stop() async throws
    /// Ends the session. The TV goes back to its home screen.
    func close() async
}

nonisolated extension CastSession {
    /// Only Google Cast plays the mirroring stream so far.
    func playLive(url: URL, title: String) async throws {
        throw TVError.unsupportedCasting
    }
}

/// One voice session with a TV. The audio is 16-bit PCM, 8 kHz, mono. It goes to the TV and nowhere
/// else, and is never stored or logged.
nonisolated protocol VoiceSession: Sendable {
    func send(_ pcm: Data) async throws
    func end() async
}

/// What the pointer surface asks a TV to do. Only numbers go to the TV, and nothing is stored.
nonisolated enum PointerCommand: Sendable, Equatable {
    /// Moves the cursor by this many points, right and down being positive.
    case move(dx: Int, dy: Int)
    case click
    /// Scrolls by this many steps. Which sign scrolls which way is UNVERIFIED.
    case scroll(dx: Int, dy: Int)
}

/// How text is typed on a TV that has more than one way. Debug builds can force one to compare them.
nonisolated enum TextInputMethod: Sendable, Equatable {
    /// The controller picks.
    case automatic
    /// One key press per character, as a press message then a release message.
    case keyPresses
    /// One key press per character, as a single "short" tap message (the reference library's default).
    case keyTaps
    /// Through the TV's input method (its text field), as one edit.
    case inputMethod
}

/// What the keyboard sheet asks a TV to do. The text is never logged or stored (CLAUDE.md).
nonisolated enum TextCommand: Sendable, Equatable {
    case insert(String)
    case backspace
    case enter
}

nonisolated extension TVController {
    /// A controller that cannot type says so, instead of failing silently.
    func send(_ text: TextCommand) async throws {
        throw TVError.unsupportedText
    }

    func apps() async throws -> [TVApp] {
        throw TVError.unsupportedApps
    }

    func startVoice() async throws -> any VoiceSession {
        throw TVError.unsupportedVoice
    }

    func startCasting() async throws -> any CastSession {
        throw TVError.unsupportedCasting
    }

    func openChannel(_ number: String) async throws {
        throw TVError.unsupportedChannels
    }

    /// Only a TV with more than one way to type uses this. Others ignore it.
    func setTextInputMethod(_ method: TextInputMethod) async {}

    func launch(_ app: TVApp) async throws {
        throw TVError.unsupportedApps
    }

    func hardwareAddresses() async -> [MACAddress] {
        []
    }

    func send(_ pointer: PointerCommand) async throws {
        throw TVError.unsupportedPointer
    }
}
