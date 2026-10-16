//
//  KeyCommand.swift
//  tvRemoteDemo
//
//  The brand-neutral remote keys. Each brand's controller translates a `KeyCommand` into its own
//  protocol (for example Roku's `Rev` and `Fwd`), which is not built yet.
//
//  The vocabulary follows `RemoteKey` in SmartCastKit, Core/Models.swift
//  (https://github.com/yuri-rod/smart-tv-remote-swift, MIT, copyright 2026 Yuri Barreira). Only the
//  names of the keys are taken from it, no code. The keys are limited to what the README scope
//  table lists (volume, mute, channel, navigation, playback, power).
//

import Foundation

nonisolated enum KeyCommand: String, Sendable, CaseIterable, Hashable {
    case power
    case volumeUp
    case volumeDown
    case mute
    case channelUp
    case channelDown
    case up
    case down
    case left
    case right
    case select
    case back
    case home
    case menu
    case rewind
    case playPause
    case fastForward
    // Shown only on the Google TV layout. Other TVs have no equivalent and answer "no such key".
    case input
    case settings
    case guide
    case info
    // Switch straight to an HDMI port. Roku, LG and Android / Google TV only.
    case hdmi1
    case hdmi2
    case hdmi3
    case hdmi4
    // Opens the TV's own live TV (its tuner or antenna / cable input).
    case liveTV
    // Media keys. Roku's single Play key is already `playPause`, so it has none of these.
    case play, pause, stop, next, previous
    // The coloured keys of a TV remote, used by teletext and some apps.
    case red, green, yellow, blue
    // Leaves the current screen (a menu or a guide). Subtitles / closed captions on or off.
    case exit, subtitles
    // The number keys of the number pad. A Roku has none: its digit goes into a focused text field.
    case digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9

    /// The digit a number key stands for, nil for every other key.
    var digitValue: Int? {
        switch self {
        case .digit0: return 0
        case .digit1: return 1
        case .digit2: return 2
        case .digit3: return 3
        case .digit4: return 4
        case .digit5: return 5
        case .digit6: return 6
        case .digit7: return 7
        case .digit8: return 8
        case .digit9: return 9
        default: return nil
        }
    }

    /// The number key for a digit from 0 to 9, nil for anything else.
    static func digit(_ value: Int) -> KeyCommand? {
        allCases.first { $0.digitValue == value }
    }

    var displayName: String {
        switch self {
        case .power: return "Power"
        case .volumeUp: return "Volume up"
        case .volumeDown: return "Volume down"
        case .mute: return "Mute"
        case .channelUp: return "Channel up"
        case .channelDown: return "Channel down"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .select: return "OK"
        case .back: return "Back"
        case .home: return "Home"
        case .menu: return "Menu"
        case .rewind: return "Rewind"
        case .playPause: return "Play / Pause"
        case .fastForward: return "Fast forward"
        case .input: return "Input"
        case .settings: return "Settings"
        case .guide: return "Guide"
        case .info: return "Info"
        case .hdmi1: return "HDMI 1"
        case .hdmi2: return "HDMI 2"
        case .hdmi3: return "HDMI 3"
        case .hdmi4: return "HDMI 4"
        case .liveTV: return "Live TV"
        case .play: return "Play"
        case .pause: return "Pause"
        case .stop: return "Stop"
        case .next: return "Next"
        case .previous: return "Previous"
        case .red: return "Red"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .blue: return "Blue"
        case .exit: return "Exit"
        case .subtitles: return "Subtitles"
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return String(digitValue ?? 0)
        }
    }

    /// The SF Symbol on the button. A symbol missing on an older iOS just leaves the label.
    var symbolName: String {
        switch self {
        case .power: return "power"
        case .volumeUp: return "speaker.plus.fill"
        case .volumeDown: return "speaker.minus.fill"
        case .mute: return "speaker.slash.fill"
        case .channelUp: return "plus.circle.fill"
        case .channelDown: return "minus.circle.fill"
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .select: return "circle.fill"
        case .back: return "arrow.uturn.backward"
        case .home: return "house.fill"
        case .menu: return "line.horizontal.3"
        case .rewind: return "backward.fill"
        case .playPause: return "playpause.fill"
        case .fastForward: return "forward.fill"
        case .input: return "arrow.right.square"
        case .settings: return "gearshape.fill"
        case .guide: return "list.bullet.rectangle"
        case .info: return "info.circle"
        case .hdmi1, .hdmi2, .hdmi3, .hdmi4: return "cable.connector"
        case .liveTV: return "tv"
        case .play: return "play.fill"
        case .pause: return "pause.fill"
        case .stop: return "stop.fill"
        case .next: return "forward.end.fill"
        case .previous: return "backward.end.fill"
        case .red, .green, .yellow, .blue: return "circle.fill"
        case .exit: return "xmark"
        case .subtitles: return "captions.bubble"
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return "\(digitValue ?? 0).circle"
        }
    }
}
