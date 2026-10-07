//
//  AndroidTVRemoteMessages.swift
//  tvRemoteDemo
//
//  The messages of the Android / Google TV control channel (port 6466), as written up in the
//  "Google TV (aka Android TV) Remote Control (v2)" wiki of Aymkdn/assistant-freebox-cloud. Every
//  message is a varint length followed by a protobuf message, the same framing as pairing.
//
//  Flow: the TV sends its configuration (field 1) -> we send ours -> the TV acknowledges (a field 1
//  message and an empty field 2) -> we send the second configuration -> the TV sends its power,
//  current app and volume, which are ignored. From then on keys are field 10 messages and the TV
//  sends pings (field 8) that must be answered with a pong (field 9), or it closes the connection.
//
//  Byte-checked offline against the wiki's examples: the configuration, the second configuration,
//  the volume-up press and release, the channel-up key and the pong.
//

import Foundation

nonisolated enum AndroidTVRemoteMessages {
    /// Field numbers of the messages in the envelope.
    private enum Field: Int {
        case configuration = 1
        case setActive = 2
        case pingRequest = 8
        case pingResponse = 9
        case keyInject = 10
        case imeKeyInject = 20
        case voiceBegin = 30
        case voicePayload = 31
        case voiceEnd = 32
        case imeBatchEdit = 21
        case imeShowRequest = 22
        case deepLink = 90
    }

    /// The feature bits the wiki sends in both configuration messages (`8, 238, 4`).
    private static let clientFeatures = 622

    /// Sent as the client's package name. The wiki's example bytes spell it "androitv-remote", a typo
    /// for its own text "androidtv-remote". The TV is not expected to check it (UNVERIFIED).
    private static let packageName = "androidtv-remote"
    private static let appVersion = "1.0.0"

    /// How a key is pressed. `short` is a press and release in one message.
    private enum Direction: Int {
        case press = 1
        case release = 2
        case short = 3
    }

    // MARK: - What we send

    /// Our answer to the TV's first configuration message.
    static func configuration() -> Data {
        var device = ProtoWriter()
        device.varint(field: 3, 1)
        device.string(field: 4, "1")
        device.string(field: 5, packageName)
        device.string(field: 6, appVersion)

        var body = ProtoWriter()
        body.varint(field: 1, clientFeatures)
        body.message(field: 2, device.bytes)

        var message = ProtoWriter()
        message.message(field: Field.configuration.rawValue, body.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    /// Sent after the TV acknowledges our configuration.
    static func secondConfiguration() -> Data {
        var body = ProtoWriter()
        body.varint(field: 1, clientFeatures)

        var message = ProtoWriter()
        message.message(field: Field.setActive.rawValue, body.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    /// The messages to send for one key. Channel keys are a single short press, as in the wiki.
    /// Every other key is a press followed by a release.
    static func keyFrames(for key: KeyCommand) -> [Data] {
        let code = keyCode(for: key)
        switch key {
        case .channelUp, .channelDown:
            return [keyFrame(code: code, direction: .short)]
        default:
            return [keyFrame(code: code, direction: .press), keyFrame(code: code, direction: .release)]
        }
    }

    /// The messages that type `text` as key presses, the way a keyboard would, or nil if any
    /// character has no key. Key presses are what Backspace and Enter use, and they are known to
    /// reach a focused text field. Capital letters are typed as lowercase (no Shift is sent).
    static func keyFrames(forText text: String, asTaps: Bool = false) -> [Data]? {
        var frames: [Data] = []
        for character in text {
            guard let code = keyCode(forCharacter: character) else {
                return nil
            }
            if asTaps {
                // One message with direction SHORT, as AndroidTVRemoteControl's `KeyPress` sends by default.
                frames.append(keyFrame(code: code, direction: .short))
            } else {
                frames.append(keyFrame(code: code, direction: .press))
                frames.append(keyFrame(code: code, direction: .release))
            }
        }
        return frames
    }

    /// The message that types `text` into the text field focused on the TV, through its input
    /// method (the way Google's own remote app does). It is field 21, an `RemoteImeBatchEdit`, with
    /// one edit that inserts the text. `imeCounter` and `fieldCounter` are the latest values the TV
    /// sent in its own field 21 messages (see `inputMethodUpdate(in:)`); the TV ignores an edit whose
    /// counters are stale. As in androidtvremote2 (Apache-2.0, `remote.py`, `send_text`), both
    /// `start` and `end` are the text's length minus one.
    static func textFrame(_ text: String, imeCounter: Int, fieldCounter: Int) -> Data {
        let position = max(text.unicodeScalars.count - 1, 0)

        var object = ProtoWriter()
        object.varint(field: 1, position)
        object.varint(field: 2, position)
        object.string(field: 3, text)

        var edit = ProtoWriter()
        edit.varint(field: 1, 1)
        edit.message(field: 2, object.bytes)

        var batch = ProtoWriter()
        batch.varint(field: 1, max(imeCounter, 0))
        batch.varint(field: 2, max(fieldCounter, 0))
        batch.message(field: 3, edit.bytes)

        var message = ProtoWriter()
        message.message(field: Field.imeBatchEdit.rawValue, batch.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    /// What a message from the TV says about the input method (text field).
    struct InputMethodUpdate: Equatable {
        var kind: String
        /// The new `ime_counter`, when the message carries one.
        var imeCounter: Int?
        /// The new `field_counter`, when the message carries one.
        var fieldCounter: Int?
        /// A short description for the log. Never the text of the field.
        var detail: String
    }

    /// The input-method counters a message from the TV carries, or nil if it has none. Three
    /// messages do (messages and fields from androidtvremote2's `remotemessage.proto`, Apache-2.0):
    /// - field 21 (`RemoteImeBatchEdit`): `ime_counter` and `field_counter`, the values an edit uses.
    /// - field 20 (`RemoteImeKeyInject`): the app's `counter` (RemoteAppInfo field 1) and the text
    ///   field's `counter_field`.
    /// - field 22 (`RemoteImeShowRequest`): the text field's `counter_field`, sent when a field is
    ///   focused.
    /// UNVERIFIED: that the counters of fields 20 and 22 are the ones an edit must carry. The library
    /// only reads field 21. They are used because field 21 may never arrive before the first edit.
    static func inputMethodUpdate(in fields: [ProtoField]) -> InputMethodUpdate? {
        for field in fields {
            guard case .bytes(let inner) = field.value,
                  let innerFields = ProtoReader.fields(in: inner) else {
                continue
            }
            switch field.number {
            case Field.imeBatchEdit.rawValue:
                let ime = number(1, in: innerFields)
                let fieldCounter = number(2, in: innerFields)
                let edits = innerFields.filter { $0.number == 3 }.count
                return InputMethodUpdate(
                    kind: "batch edit (21)",
                    imeCounter: ime,
                    fieldCounter: fieldCounter,
                    detail: "ime=\(ime) field=\(fieldCounter) edits=\(edits)"
                )
            case Field.imeKeyInject.rawValue:
                let app = nested(1, in: innerFields)
                let status = nested(2, in: innerFields)
                let ime = app.map { number(1, in: $0) }
                let fieldCounter = status.map { number(1, in: $0) }
                let package = app.flatMap { text(12, in: $0) } ?? "?"
                let cursor = status.map { "\(number(3, in: $0))-\(number(4, in: $0))" } ?? "?"
                return InputMethodUpdate(
                    kind: "key inject (20)",
                    imeCounter: ime,
                    fieldCounter: fieldCounter,
                    detail: "app=\(package) ime=\(ime.map(String.init) ?? "-") field=\(fieldCounter.map(String.init) ?? "-") cursor=\(cursor)"
                )
            case Field.imeShowRequest.rawValue:
                let status = nested(2, in: innerFields)
                let fieldCounter = status.map { number(1, in: $0) }
                let cursor = status.map { "\(number(3, in: $0))-\(number(4, in: $0))" } ?? "?"
                return InputMethodUpdate(
                    kind: "show request (22)",
                    imeCounter: nil,
                    fieldCounter: fieldCounter,
                    detail: "field=\(fieldCounter.map(String.init) ?? "-") cursor=\(cursor)"
                )
            default:
                continue
            }
        }
        return nil
    }

    /// The field numbers of a message from the TV, for the log, or nil for a ping (which comes
    /// every few seconds and is not worth a line).
    static func summary(of fields: [ProtoField]) -> String? {
        let numbers = fields.map(\.number)
        guard numbers != [Field.pingRequest.rawValue] else { return nil }
        return "fields " + numbers.map(String.init).joined(separator: ", ")
    }

    private static func number(_ number: Int, in fields: [ProtoField]) -> Int {
        Int(clamping: fields.first(where: { $0.number == number })?.varintValue ?? 0)
    }

    private static func nested(_ number: Int, in fields: [ProtoField]) -> [ProtoField]? {
        guard let field = fields.first(where: { $0.number == number }),
              case .bytes(let inner) = field.value else {
            return nil
        }
        return ProtoReader.fields(in: inner)
    }

    private static func text(_ number: Int, in fields: [ProtoField]) -> String? {
        guard let field = fields.first(where: { $0.number == number }),
              case .bytes(let bytes) = field.value else {
            return nil
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func backspaceFrames() -> [Data] {
        [keyFrame(code: 67, direction: .press), keyFrame(code: 67, direction: .release)]   // KEYCODE_DEL
    }

    static func enterFrames() -> [Data] {
        [keyFrame(code: 66, direction: .press), keyFrame(code: 66, direction: .release)]   // KEYCODE_ENTER
    }

    /// Opens a web address on the TV, which hands it to the app that handles it. The message is
    /// field 90 holding the address as field 1, as in AndroidTVRemoteControl's `DeepLink.swift`.
    static func deepLinkFrame(url: String) -> Data {
        var link = ProtoWriter()
        link.string(field: 1, url)

        var message = ProtoWriter()
        message.message(field: Field.deepLink.rawValue, link.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    // MARK: - Voice
    //
    // The voice feature, from androidtvremote2 (Apache-2.0, `remote.py` and `remotemessage.proto`):
    // send the Search key, the TV answers with a voice begin (field 30) carrying a session id, we send
    // a voice begin back with that id, then stream voice payloads (field 31) and finish with a voice
    // end (field 32). The samples are 16-bit PCM, 8 kHz, mono, in chunks of at most 20 KB. A chunk
    // under 8 KB is padded with zero bytes, because a Shield TV refused smaller ones.

    private static let voiceChunkMaximum = 20 * 1024
    private static let voiceChunkMinimum = 8 * 1024

    /// The Search key (`KEYCODE_SEARCH`, 84) as one short tap. It makes the TV start a voice session.
    static func assistantKeyFrame() -> Data {
        keyFrame(code: 84, direction: .short)
    }

    /// The session id in a voice begin from the TV, or nil if the message is not one.
    static func voiceSessionID(in fields: [ProtoField]) -> Int? {
        guard let begin = fields.first(where: { $0.number == Field.voiceBegin.rawValue }),
              case .bytes(let inner) = begin.value,
              let innerFields = ProtoReader.fields(in: inner) else {
            return nil
        }
        return number(1, in: innerFields)
    }

    static func voiceBeginFrame(sessionID: Int) -> Data {
        var begin = ProtoWriter()
        begin.varint(field: 1, max(sessionID, 0))
        var message = ProtoWriter()
        message.message(field: Field.voiceBegin.rawValue, begin.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    /// The payload messages for some audio: at most 20 KB each, and each padded to at least 8 KB.
    static func voicePayloadFrames(sessionID: Int, pcm: Data) -> [Data] {
        var frames: [Data] = []
        var start = 0
        while start < pcm.count {
            let end = min(start + voiceChunkMaximum, pcm.count)
            var samples = Array(pcm[pcm.startIndex + start ..< pcm.startIndex + end])
            if samples.count < voiceChunkMinimum {
                samples += [UInt8](repeating: 0, count: voiceChunkMinimum - samples.count)
            }
            var payload = ProtoWriter()
            payload.varint(field: 1, max(sessionID, 0))
            payload.message(field: 2, samples)
            var message = ProtoWriter()
            message.message(field: Field.voicePayload.rawValue, payload.bytes)
            frames.append(AndroidTVPairingMessages.frame(message.bytes))
            start = end
        }
        return frames
    }

    static func voiceEndFrame(sessionID: Int) -> Data {
        var end = ProtoWriter()
        end.varint(field: 1, max(sessionID, 0))
        var message = ProtoWriter()
        message.message(field: Field.voiceEnd.rawValue, end.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    /// The answer to a ping. It repeats the ping's value.
    /// UNVERIFIED: the wiki says a pong needs no length prefix, but every other message has one and
    /// the reference implementation is unclear. It is framed like the rest. If the TV keeps closing
    /// the connection, this is the first thing to check.
    static func pong(value: UInt64) -> Data {
        var body = ProtoWriter()
        body.varint(field: 1, Int(clamping: value))

        var message = ProtoWriter()
        message.message(field: Field.pingResponse.rawValue, body.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }

    // MARK: - What we read

    /// The TV's first message: its configuration.
    static func isServerConfiguration(_ fields: [ProtoField]) -> Bool {
        fields.contains { $0.number == Field.configuration.rawValue }
    }

    /// The TV's acknowledgement of our configuration: the empty field 2 message (`18, 0`).
    static func isSetActive(_ fields: [ProtoField]) -> Bool {
        fields.contains { $0.number == Field.setActive.rawValue }
    }

    /// The value to echo in the pong if this message is a ping, otherwise nil.
    static func pingValue(in fields: [ProtoField]) -> UInt64? {
        guard let ping = fields.first(where: { $0.number == Field.pingRequest.rawValue }),
              case .bytes(let inner) = ping.value else {
            return nil
        }
        let value = ProtoReader.fields(in: inner)?.first(where: { $0.number == 1 })?.varintValue
        return value ?? 0
    }

    // MARK: - Keys

    /// Whether an Android / Google TV has a key for this. Only Exit has none.
    static func supports(_ key: KeyCommand) -> Bool {
        key != .exit
    }

    /// The Android `KeyEvent` code for a key. The wiki confirms volume up (24) and channel up (166),
    /// and AndroidTVRemoteControl's `Key.swift` (MIT) lists every code below.
    static func keyCode(for key: KeyCommand) -> Int {
        switch key {
        case .home: return 3            // KEYCODE_HOME
        case .back: return 4            // KEYCODE_BACK
        case .up: return 19             // KEYCODE_DPAD_UP
        case .down: return 20           // KEYCODE_DPAD_DOWN
        case .left: return 21           // KEYCODE_DPAD_LEFT
        case .right: return 22          // KEYCODE_DPAD_RIGHT
        case .select: return 23         // KEYCODE_DPAD_CENTER
        case .volumeUp: return 24       // KEYCODE_VOLUME_UP
        case .volumeDown: return 25     // KEYCODE_VOLUME_DOWN
        case .power: return 26          // KEYCODE_POWER
        case .menu: return 82           // KEYCODE_MENU
        case .playPause: return 85      // KEYCODE_MEDIA_PLAY_PAUSE
        case .rewind: return 89         // KEYCODE_MEDIA_REWIND
        case .fastForward: return 90    // KEYCODE_MEDIA_FAST_FORWARD
        case .mute: return 164          // KEYCODE_VOLUME_MUTE
        case .channelUp: return 166     // KEYCODE_CHANNEL_UP
        case .channelDown: return 167   // KEYCODE_CHANNEL_DOWN
        case .input: return 178         // KEYCODE_TV_INPUT
        case .settings: return 176      // KEYCODE_SETTINGS
        case .guide: return 172         // KEYCODE_GUIDE
        case .info: return 165          // KEYCODE_INFO
        case .hdmi1: return 243         // KEYCODE_TV_INPUT_HDMI_1
        case .hdmi2: return 244         // KEYCODE_TV_INPUT_HDMI_2
        case .hdmi3: return 245         // KEYCODE_TV_INPUT_HDMI_3
        case .hdmi4: return 246         // KEYCODE_TV_INPUT_HDMI_4
        case .liveTV: return 170        // KEYCODE_TV
        // Android's KeyEvent constants, from memory (UNVERIFIED on a TV).
        case .play: return 126          // KEYCODE_MEDIA_PLAY
        case .pause: return 127         // KEYCODE_MEDIA_PAUSE
        case .stop: return 86           // KEYCODE_MEDIA_STOP
        case .next: return 87           // KEYCODE_MEDIA_NEXT
        case .previous: return 88       // KEYCODE_MEDIA_PREVIOUS
        case .red: return 183           // KEYCODE_PROG_RED
        case .green: return 184         // KEYCODE_PROG_GREEN
        case .yellow: return 185        // KEYCODE_PROG_YELLOW
        case .blue: return 186          // KEYCODE_PROG_BLUE
        case .subtitles: return 175     // KEYCODE_CAPTIONS
        // Android has no Exit key (see `supports(_:)`): this is never sent.
        case .exit: return 4
        // KEYCODE_0 to KEYCODE_9 are 7 to 16, the same codes typed text uses.
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return 7 + (key.digitValue ?? 0)
        }
    }

    /// The key for a typed character. Codes are Android `KeyEvent` constants, as listed in
    /// AndroidTVRemoteControl's `Key.swift` (MIT): A-Z 29-54, 0-9 7-16, space 62, comma 55, period 56,
    /// minus 69, equals 70, semicolon 74, apostrophe 75, slash 76, at 77. Nil for anything else.
    static func keyCode(forCharacter character: Character) -> Int? {
        let lowered = character.lowercased()
        guard lowered.count == 1, let ascii = lowered.first?.asciiValue else {
            return nil
        }
        switch ascii {
        case UInt8(ascii: "a")...UInt8(ascii: "z"): return 29 + Int(ascii - UInt8(ascii: "a"))
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return 7 + Int(ascii - UInt8(ascii: "0"))
        case UInt8(ascii: " "): return 62
        case UInt8(ascii: ","): return 55
        case UInt8(ascii: "."): return 56
        case UInt8(ascii: "-"): return 69
        case UInt8(ascii: "="): return 70
        case UInt8(ascii: ";"): return 74
        case UInt8(ascii: "'"): return 75
        case UInt8(ascii: "/"): return 76
        case UInt8(ascii: "@"): return 77
        default: return nil
        }
    }

    private static func keyFrame(code: Int, direction: Direction) -> Data {
        var inject = ProtoWriter()
        inject.varint(field: 1, code)
        inject.varint(field: 2, direction.rawValue)

        var message = ProtoWriter()
        message.message(field: Field.keyInject.rawValue, inject.bytes)
        return AndroidTVPairingMessages.frame(message.bytes)
    }
}
