//
//  ControlPorts.swift
//  tvRemoteDemo
//

import Foundation

/// A TCP port a TV brand is believed to use for remote control.
nonisolated struct ControlPort: Sendable, Equatable {
    var port: UInt16
    /// The brand this port belongs to. Nil when it belongs to a platform many brands share.
    var brand: TVBrand?
    /// True only when the number is confirmed by a document in this repo.
    var isVerified: Bool
}

nonisolated enum ControlPorts {
    static let rokuECP: UInt16 = 8060

    /// Google Cast (CASTV2), used for casting to a Chromecast, Google TV or Android TV. From pychromecast
    /// (MIT). It is not swept during discovery.
    static let googleCast: UInt16 = 8009

    /// Ports swept across the subnet. Each one has a brand check that proves what owns it (Roku's device-info
    /// reply, a Samsung TV's JSON description, an LG TV's SSAP error reply: see `BrandProbes`), because an
    /// open port that nothing confirms would only produce false positives such as routers.
    static var verified: [ControlPort] {
        all.filter(\.isVerified)
    }

    /// Verified ports for one brand.
    static func verifiedPorts(for brand: TVBrand) -> [UInt16] {
        verified.filter { $0.brand == brand }.map(\.port)
    }

    /// All verified ports, with the ones of `brand` first.
    static func verifiedPorts(preferring brand: TVBrand?) -> [UInt16] {
        let ports = verified
        guard let brand else { return ports.map(\.port) }
        return (ports.filter { $0.brand == brand } + ports.filter { $0.brand != brand }).map(\.port)
    }

    /// Known control ports. Only the ones with a brand check are swept (see `verified`). An open port never
    /// identifies a brand by itself.
    static let all: [ControlPort] = [
        // Roku External Control Protocol. Documented in README.md (Roku quick reference).
        ControlPort(port: rokuECP, brand: .roku, isVerified: true),

        // Samsung: 8001 is the plain REST and WebSocket port (the Samsung controller uses it), 8002 the
        // secure one. Only 8001 is swept: its JSON description proves a Samsung TV.
        ControlPort(port: 8001, brand: .samsung, isVerified: true),
        ControlPort(port: 8002, brand: .samsung, isVerified: false),
        // LG webOS: 3001 secure and 3000 plain WebSocket (lgtv2's README, and the LG controller). Port 3000
        // is also a common dev-server port, so an open port is never enough: the SSAP error reply is.
        ControlPort(port: 3001, brand: .lg, isVerified: true),
        ControlPort(port: 3000, brand: .lg, isVerified: true),
        // UNVERIFIED from here on (from memory). Each needs its source checked before it is trusted.
        // Android / Google TV is a platform that TCL, Hisense, Sony and others share, so no brand.
        // Port 6467 is the pairing port in odyshewroman/AndroidTVRemoteControl (MIT), which is
        // still only a reference, so both stay unverified here.
        // TODO(source): confirm 6466 (remote) against AndroidTVRemoteControl.
        ControlPort(port: 6466, brand: nil, isVerified: false),
        ControlPort(port: 6467, brand: nil, isVerified: false),
        // TODO(source): Vizio SmartCast ports; check SmartCastKit.
        ControlPort(port: 7345, brand: .vizio, isVerified: false),
        ControlPort(port: 9000, brand: .vizio, isVerified: false)

        // Sony is left out on purpose. Its only candidate is port 80, which every router and
        // printer also opens, so it says nothing. TODO(source): Sony's Bravia REST docs, and
        // identify Sony through SSDP instead.
    ]
}
