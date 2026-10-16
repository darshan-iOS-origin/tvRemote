//
//  TVPlatform.swift
//  tvRemoteDemo
//

import Foundation

/// The control protocol a TV speaks. It decides how the TV is paired and controlled.
/// A brand and a platform are different things: TCL, Hisense and Sony TVs run Android / Google TV,
/// and TCL and Hisense also make Roku TVs.
nonisolated enum TVPlatform: String, Sendable, CaseIterable {
    case roku
    case tizen
    case webOS
    case androidTV
    case smartCast
    /// Sony Bravia's own IP control (REST and IRCC), for a Bravia that is not controlled as an Android TV.
    case bravia
    /// Amazon Fire TV: a local HTTPS API with a PIN (navigation, apps and wake only).
    case fireTV
    case unknown

    /// Bonjour service type to platform.
    /// Every type here must also be listed under `NSBonjourServices` in Info.plist.
    /// No AirPlay or companion-link types: Apple TV is out of scope.
    static let bonjourServiceTypeTable: [String: TVPlatform] = [
        // Named in README.md (Setup, step 3).
        "_androidtvremote2._tcp": .androidTV,
        // UNVERIFIED (from memory). TODO: confirm against Samsung's Multiscreen docs or TVCommanderKit.
        "_samsungmsf._tcp": .tizen,
        // A Fire TV advertises this (two community sources). UNVERIFIED on a device.
        "_amzn-wplay._tcp": .fireTV
    ]

    /// Identifies the platform from a Bonjour service type such as `_androidtvremote2._tcp.`.
    static func identify(bonjourServiceType: String) -> TVPlatform {
        var type = bonjourServiceType.lowercased()
        while type.hasSuffix(".") {
            type.removeLast()
        }
        if type.hasSuffix(".local") {
            type.removeLast(".local".count)
        }
        return bonjourServiceTypeTable[type] ?? .unknown
    }

    /// The platform a brand's TVs run, judged from the manufacturer on an SSDP TV/media response.
    /// UNVERIFIED assumption: a Samsung TV is a 2016+ Tizen TV and an LG TV is webOS 3 or newer.
    /// Roku is not inferred here. It is only set once the TV answers Roku's device-info request.
    static func inferred(from brand: TVBrand) -> TVPlatform {
        switch brand {
        case .samsung: return .tizen
        case .lg: return .webOS
        case .vizio: return .smartCast
        // A Sony that also advertises the Android TV remote is merged into an Android TV instead.
        case .sony: return .bravia
        case .fireTV: return .fireTV
        default: return .unknown
        }
    }

    /// The brand this platform implies, when only one maker uses it.
    var impliedBrand: TVBrand? {
        switch self {
        case .tizen: return .samsung
        case .webOS: return .lg
        case .smartCast: return .vizio
        case .bravia: return .sony
        case .fireTV: return .fireTV
        case .roku, .androidTV, .unknown: return nil
        }
    }

    var displayName: String {
        switch self {
        case .roku: return "Roku"
        case .tizen: return "Samsung Tizen"
        case .webOS: return "LG webOS"
        case .androidTV: return "Android / Google TV"
        case .smartCast: return "Vizio SmartCast"
        case .bravia: return "Sony Bravia"
        case .fireTV: return "Fire TV"
        case .unknown: return "Unknown"
        }
    }

    /// What the TV needs before it accepts commands. See the table in README.md.
    var pairingKind: PairingKind {
        switch self {
        case .roku: return .none
        case .tizen, .webOS: return .approveOnTV
        case .androidTV: return .code(.androidTV)
        case .smartCast: return .code(.vizio)
        case .bravia: return .code(.sony)
        case .fireTV: return .code(.fireTV)
        case .unknown: return .unavailable
        }
    }
}
