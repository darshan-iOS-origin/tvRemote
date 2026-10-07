//
//  VoiceCommandParser.swift
//  tvRemoteDemo
//
//  Turns what the user said into an action for the TV. It is pure: no network, no storage, and the
//  words are never logged (CLAUDE.md). Known phrases become keys, a channel, an input or an app to
//  open. Anything else is dictation, to be typed into the text box that is open on the TV.
//

import Foundation

nonisolated enum VoiceCommand: Sendable, Equatable {
    case key(KeyCommand)
    /// A channel number such as `5` or `7.1`.
    case channel(String)
    /// The spoken name of an app, matched against the TV's apps.
    case openApp(String)
    /// Words to type into the TV's open text box.
    case text(String)
}

nonisolated enum VoiceCommandParser {
    static func parse(_ transcript: String) -> VoiceCommand {
        let words = tokens(transcript)
        guard !words.isEmpty else { return .text(transcript.trimmingCharacters(in: .whitespacesAndNewlines)) }

        if let command = parseOpen(words) ?? parseChannel(words) ?? parseInput(words) {
            return command
        }
        if let key = phrases[words.joined(separator: " ")] {
            return .key(key)
        }
        return .text(transcript.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Phrases

    /// Whole phrases, after punctuation and filler words are removed.
    private static let phrases: [String: KeyCommand] = {
        var table: [String: KeyCommand] = [:]
        func add(_ key: KeyCommand, _ spoken: [String]) {
            for phrase in spoken { table[phrase] = key }
        }
        add(.volumeUp, ["volume up", "louder", "turn it up", "raise volume", "increase volume", "volume higher"])
        add(.volumeDown, ["volume down", "quieter", "turn it down", "lower volume", "decrease volume", "volume lower"])
        add(.mute, ["mute", "unmute", "silence", "be quiet"])
        add(.home, ["home", "go home", "home screen"])
        add(.back, ["back", "go back"])
        add(.up, ["up"])
        add(.down, ["down"])
        add(.left, ["left"])
        add(.right, ["right"])
        add(.select, ["ok", "okay", "select", "enter", "confirm"])
        add(.playPause, ["play", "pause", "resume", "play pause", "play or pause"])
        add(.stop, ["stop"])
        add(.exit, ["exit"])
        add(.subtitles, ["subtitles", "captions", "closed captions", "subtitles on", "subtitles off"])
        add(.rewind, ["rewind"])
        add(.fastForward, ["fast forward", "forward"])
        add(.power, [
            "power", "power off", "power on", "turn off", "turn on", "switch off", "switch on",
            "tv off", "tv on", "turn tv off", "turn tv on", "turn off tv", "turn on tv", "switch tv off", "switch tv on"
        ])
        add(.menu, ["menu"])
        add(.settings, ["settings"])
        add(.guide, ["guide", "tv guide"])
        add(.info, ["info", "information"])
        add(.liveTV, ["live tv", "live television", "watch tv", "watch live tv"])
        add(.channelUp, ["channel up", "next channel"])
        add(.channelDown, ["channel down", "previous channel"])
        add(.input, ["input", "inputs", "change input", "switch input"])
        return table
    }()

    private static let fillers: Set<String> = ["please", "the", "a", "hey"]

    /// Lower-case words without punctuation (a dot inside a number stays), filler words dropped.
    private static func tokens(_ text: String) -> [String] {
        let cleaned = text.lowercased().map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : " " }
        return String(cleaned).split(separator: " ")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty && !fillers.contains($0) }
    }

    // MARK: - Open an app

    private static func parseOpen(_ words: [String]) -> VoiceCommand? {
        guard let first = words.first, ["open", "launch", "start"].contains(first), words.count > 1 else {
            return nil
        }
        return .openApp(words.dropFirst().joined(separator: " "))
    }

    // MARK: - Channels and inputs

    private static func parseChannel(_ words: [String]) -> VoiceCommand? {
        var rest = words
        if rest.first == "go", rest.dropFirst().first == "to" { rest.removeFirst(2) }
        guard rest.first == "channel", rest.count > 1 else { return nil }
        let spoken = Array(rest.dropFirst())
        if spoken == ["up"] || spoken == ["down"] { return nil }
        guard let number = digits(from: spoken), ChannelNumber.isValid(number) else { return nil }
        return .channel(number)
    }

    private static let hdmiKeys: [String: KeyCommand] = ["1": .hdmi1, "2": .hdmi2, "3": .hdmi3, "4": .hdmi4]

    /// "hdmi 2", "hdmi two", "switch to hdmi 3", "change input to hdmi 1" and "input 2".
    private static func parseInput(_ words: [String]) -> VoiceCommand? {
        if words.count == 2, words[0] == "input", let number = digits(from: [words[1]]), let key = hdmiKeys[number] {
            return .key(key)
        }
        guard let index = words.firstIndex(of: "hdmi"),
              words[..<index].allSatisfy({ ["input", "switch", "change", "to", "go"].contains($0) }),
              let number = digits(from: Array(words[(index + 1)...])),
              let key = hdmiKeys[number] else {
            return nil
        }
        return .key(key)
    }

    private static let numberWords = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9"
    ]

    /// "five" becomes 5, "seven point one" becomes 7.1, "12" stays 12. Nil for anything else.
    private static func digits(from words: [String]) -> String? {
        guard !words.isEmpty else { return nil }
        var result = ""
        for word in words {
            if word == "point" || word == "dot" {
                result += "."
            } else if let digit = numberWords[word] {
                result += digit
            } else if word.allSatisfy({ $0.isNumber || $0 == "." }) {
                result += word
            } else {
                return nil
            }
        }
        return result.isEmpty ? nil : result
    }

    // MARK: - Matching an app name

    /// The app whose name best matches what was said: an exact match first, then a name that contains
    /// the spoken words, then spoken words that contain the name.
    static func match(appName spoken: String, in apps: [TVApp]) -> TVApp? {
        let wanted = normalize(spoken)
        guard !wanted.isEmpty else { return nil }
        let named = apps.map { (app: $0, name: normalize($0.name)) }.filter { !$0.name.isEmpty }
        return named.first { $0.name == wanted }?.app
            ?? named.first { $0.name.contains(wanted) }?.app
            ?? named.first { wanted.contains($0.name) }?.app
    }

    private static func normalize(_ text: String) -> String {
        String(text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ").joined(separator: " ")
    }
}
