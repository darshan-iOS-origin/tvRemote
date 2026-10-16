//
//  TVPairing.swift
//  tvRemoteDemo
//
//  The brand-neutral pairing types. Screens talk to `PairingManager`, never to a brand class.
//

import Foundation

/// Which characters a pairing code may contain.
nonisolated enum PairingCodeCharacters: Sendable, Equatable {
    case digits
    case hexadecimal

    func allows(_ character: Character) -> Bool {
        switch self {
        case .digits:
            return character.isASCII && character.isNumber
        case .hexadecimal:
            return character.isASCII && character.isHexDigit
        }
    }
}

/// What a code typed by the user must look like before we send it to the TV.
/// This only rejects obvious typos. The TV decides whether a code is right.
nonisolated struct PairingCodeFormat: Sendable, Equatable {
    var lengths: ClosedRange<Int>
    var characters: PairingCodeCharacters

    /// Android / Google TV shows six hexadecimal characters.
    /// Source: odyshewroman/AndroidTVRemoteControl README (MIT).
    static let androidTV = PairingCodeFormat(lengths: 6...6, characters: .hexadecimal)

    /// Vizio shows a PIN on the TV. Its length is UNVERIFIED (the library that documents the calls
    /// does not say), so anything from 4 to 8 digits is accepted until it is tested on a real TV.
    static let vizio = PairingCodeFormat(lengths: 4...8, characters: .digits)

    /// A Sony Bravia shows a four-digit PIN (pybravia, sony_bravia_psk).
    static let sony = PairingCodeFormat(lengths: 4...4, characters: .digits)

    /// A Fire TV shows a four-digit PIN (hms-firetv, FireTVRest).
    static let fireTV = PairingCodeFormat(lengths: 4...4, characters: .digits)

    /// The text without spaces and dashes, in upper case.
    func normalized(_ text: String) -> String {
        text.filter { !$0.isWhitespace && $0 != "-" }.uppercased()
    }

    func isValid(_ text: String) -> Bool {
        let code = normalized(text)
        return lengths.contains(code.count) && code.allSatisfy { characters.allows($0) }
    }

    /// A short hint for the entry screen.
    var hint: String {
        let length = lengths.lowerBound == lengths.upperBound
            ? "\(lengths.lowerBound)"
            : "\(lengths.lowerBound) to \(lengths.upperBound)"
        switch characters {
        case .digits:
            return "\(length) digits"
        case .hexadecimal:
            return "\(length) characters, 0-9 and A-F"
        }
    }
}

/// What a TV needs before it accepts commands.
nonisolated enum PairingKind: Sendable, Equatable {
    /// Nothing (Roku).
    case none
    /// The TV shows an Allow / Accept prompt. No code is typed (Samsung, LG).
    case approveOnTV
    /// The TV shows a code the user types into the app (Vizio, Android / Google TV).
    case code(PairingCodeFormat)
    /// We do not know how to pair this TV.
    case unavailable

    /// A few words for list rows. Nil when unknown.
    var shortDescription: String? {
        switch self {
        case .none: return "No code needed"
        case .approveOnTV: return "Approve on TV"
        case .code: return "Enter a code"
        case .unavailable: return nil
        }
    }
}

/// What `start` hands back so the code can be submitted later. Opaque to the screens.
nonisolated struct PairingChallenge: Sendable, Equatable {
    var platform: TVPlatform
    /// The TV's pairing request token (Vizio: `PAIRING_REQ_TOKEN`).
    var token: String
    /// The id this app used for the request. The TV lists it as the paired device.
    var deviceID: String
    /// The port that answered.
    var port: UInt16
    /// The TV's address, so a token earned by the code can be kept for that TV (Vizio).
    var host: String = ""
}

nonisolated enum PairingError: Error, Sendable, Equatable {
    /// The TV did not answer.
    case unreachable
    /// The TV answered too slowly.
    case timedOut
    /// The TV is already showing a code for an earlier request.
    case alreadyPending
    /// The TV refused the request.
    case rejected
    /// The TV answered with something we cannot read.
    case badResponse
    /// This phone could not create the certificate it shows to the TV (Android / Google TV).
    case identityUnavailable
    /// The code does not match the one the TV is showing.
    case wrongCode
    /// Checking a code is not built yet for this platform.
    case notBuilt
}

/// The result of asking a TV to start pairing.
nonisolated enum PairingOutcome: Sendable, Equatable {
    /// The TV now shows a code. The user types it into the app.
    case awaitingCode(PairingCodeFormat, PairingChallenge)
    /// This TV needs no pairing.
    case noPairingNeeded
    /// Pairing for this platform is not built yet.
    case notBuilt(TVPlatform)
    /// We cannot tell how to pair this TV.
    case unavailable
    case failed(PairingError)
}

/// The result of sending the code the user typed.
nonisolated enum PairingSubmitOutcome: Sendable, Equatable {
    /// The TV accepted the code. This phone is paired.
    case paired
    /// The code does not match. The TV is still showing its code, so the user can try again.
    case wrongCode
    /// Checking codes is not built yet for this platform.
    case notBuilt(TVPlatform)
    case failed(PairingError)
}

/// One implementation per control platform, one file each.
nonisolated protocol TVPairing: Sendable {
    var platform: TVPlatform { get }

    /// Asks the TV to show its pairing code.
    func start(device: TVDevice) async throws -> PairingChallenge

    /// Gives up on a challenge that will not be finished, releasing anything kept open for it.
    func cancel(_ challenge: PairingChallenge) async

    /// Sends the code the user typed for `challenge`. Throws `PairingError.wrongCode` for a code
    /// that does not match, and `PairingError.notBuilt` where this is not built yet.
    func submit(code: String, challenge: PairingChallenge) async throws
}

nonisolated extension TVPairing {
    /// Most pairings keep nothing open between `start` and the code, so there is nothing to release.
    func cancel(_ challenge: PairingChallenge) async {}

    /// Not built until a platform implements it.
    func submit(code: String, challenge: PairingChallenge) async throws {
        throw PairingError.notBuilt
    }
}
