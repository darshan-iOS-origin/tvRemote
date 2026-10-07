//
//  TVBrand.swift
//  tvRemoteDemo
//

import Foundation

/// The TV brands the app shows. A brand is a name to display. The control protocol is a separate
/// thing, see `TVPlatform`.
/// - `.other` is a TV whose platform we know but whose maker is not listed.
/// - `.unknown` means "not sure". Such a device is never shown.
/// There is deliberately no Apple TV case (excluded for privacy reasons).
nonisolated enum TVBrand: String, Sendable, CaseIterable {
    case roku
    case samsung
    case lg
    case tcl
    case hisense
    case fireTV
    case vizio
    case sony
    case other
    case unknown

    /// Brands the user can pick, in menu order. Roku comes first because the demo controls it first.
    static let selectableBrands: [TVBrand] = [.roku, .samsung, .lg, .tcl, .hisense, .fireTV, .vizio, .sony, .other]

    /// Plain text only. Brand names are used factually, with no logos (README, known risks).
    var displayName: String {
        switch self {
        case .roku: return "Roku"
        case .samsung: return "Samsung"
        case .lg: return "LG"
        case .tcl: return "TCL"
        case .hisense: return "Hisense"
        case .fireTV: return "Fire TV"
        case .vizio: return "Vizio"
        case .sony: return "Sony"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }

    /// True when the app has a controller for this brand. The UI disables the rest.
    /// TODO: add each brand here when its controller is built. The demo controls Roku first.
    var isSupported: Bool {
        self == .roku
    }

    /// How specific a label is. When two sightings of one TV disagree, the more specific wins:
    /// a maker's name beats "Roku" (a TCL TV that runs Roku), which beats "Other".
    var specificity: Int {
        switch self {
        case .unknown: return 0
        case .other: return 1
        case .roku: return 2
        default: return 3
        }
    }

    static var bonjourServiceTypes: [String] {
        TVPlatform.bonjourServiceTypeTable.keys.sorted()
    }

    /// The Bonjour types to browse, with the ones that belong to `brand` first.
    static func orderedBonjourServiceTypes(preferring brand: TVBrand?) -> [String] {
        let all = bonjourServiceTypes
        guard let brand else { return all }
        let own = all.filter { TVPlatform.identify(bonjourServiceType: $0).impliedBrand == brand }
        return own + all.filter { !own.contains($0) }
    }

    /// An SSDP search target that only this brand answers, when we know one.
    /// UNVERIFIED (README does not list it). TODO: confirm `roku:ecp` against Roku's ECP docs.
    static let ssdpSearchTargetTable: [TVBrand: String] = [
        .roku: "roku:ecp"
    ]

    // Brand words matched as whole tokens, so "lg" does not match "Logitech" or "algorithm".
    // UNVERIFIED (from memory): the words for TCL, Hisense and Amazon (Fire TV). TODO: confirm them
    // against the manufacturer strings of real TVs, using the details screen.
    private static let brandTokens: [(token: String, brand: TVBrand)] = [
        ("roku", .roku),
        ("samsung", .samsung),
        ("lg", .lg),
        ("tcl", .tcl),
        ("hisense", .hisense),
        ("amazon", .fireTV),
        ("vizio", .vizio),
        ("sony", .sony)
    ]

    /// Identifies the brand from SSDP data. Fields are checked in order (manufacturer, server
    /// header, model name). The first field that names exactly one brand wins. A field that names
    /// several brands, or no field naming any, gives `.unknown`.
    static func identify(manufacturer: String?, modelName: String? = nil, serverHeader: String? = nil) -> TVBrand {
        for field in [manufacturer, serverHeader, modelName] {
            let matches = brands(in: field)
            if matches.count == 1, let brand = matches.first {
                return brand
            }
            if matches.count > 1 {
                return .unknown
            }
        }
        return .unknown
    }

    /// True for devices that must never be shown (Apple TV is excluded for privacy reasons).
    static func isExcluded(manufacturer: String?, modelName: String? = nil, serverHeader: String? = nil) -> Bool {
        [manufacturer, modelName, serverHeader].contains { field in
            tokens(in: field).contains { $0.hasPrefix("apple") }
        }
    }

    private static func brands(in text: String?) -> Set<TVBrand> {
        let words = Set(tokens(in: text))
        return Set(brandTokens.filter { words.contains($0.token) }.map { $0.brand })
    }

    private static func tokens(in text: String?) -> [String] {
        guard let text else { return [] }
        return text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}
