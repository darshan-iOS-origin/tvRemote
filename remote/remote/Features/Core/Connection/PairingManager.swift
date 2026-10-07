//
//  PairingManager.swift
//  tvRemoteDemo
//

import Foundation

/// The one place screens ask to pair with a TV. It picks the pairing for the TV's platform, so no
/// screen ever touches a brand class (CLAUDE.md).
///
/// Built so far: Vizio SmartCast, Sony Bravia, Fire TV and Android / Google TV, all with a code the TV shows.
/// Roku, Samsung and LG have no code to type: the screen connects through `ConnectionManager`, and
/// Samsung and LG ask for approval on the TV during that connection.
nonisolated final class PairingManager: Sendable {
    private let pairings: [TVPlatform: TVPairing]

    init(pairings: [TVPairing] = [VizioPairing(), AndroidTVPairing(), SonyPairing(), FireTVPairing()]) {
        self.pairings = Dictionary(pairings.map { ($0.platform, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// What pairing this TV needs, without contacting it.
    func kind(for device: TVDevice) -> PairingKind {
        device.platform.pairingKind
    }

    /// Starts pairing. For a TV that shows a code, the code is on the TV's screen when this returns
    /// `.awaitingCode`. Nothing is sent to the TV for a platform that needs no pairing or whose
    /// pairing is not built yet.
    func start(_ device: TVDevice) async -> PairingOutcome {
        switch device.platform.pairingKind {
        case .none:
            return .noPairingNeeded
        case .unavailable:
            return .unavailable
        case .approveOnTV:
            return .notBuilt(device.platform)
        case .code(let format):
            guard let pairing = pairings[device.platform] else {
                return .notBuilt(device.platform)
            }
            do {
                let challenge = try await pairing.start(device: device)
                return .awaitingCode(format, challenge)
            } catch let error as PairingError {
                return .failed(error)
            } catch {
                return .failed(.unreachable)
            }
        }
    }

    /// Sends the code the user typed. The TV decides whether it is right: the app relays it, and for
    /// Android / Google TV also catches an obvious mismatch before sending anything.
    func submit(code: String, challenge: PairingChallenge) async -> PairingSubmitOutcome {
        guard let pairing = pairings[challenge.platform] else {
            return .notBuilt(challenge.platform)
        }
        do {
            try await pairing.submit(code: code, challenge: challenge)
            return .paired
        } catch PairingError.wrongCode {
            return .wrongCode
        } catch PairingError.notBuilt {
            return .notBuilt(challenge.platform)
        } catch let error as PairingError {
            return .failed(error)
        } catch {
            return .failed(.unreachable)
        }
    }

    /// Gives up on a challenge from `start`, for example when the user closes the pairing screen.
    func cancel(_ challenge: PairingChallenge) async {
        await pairings[challenge.platform]?.cancel(challenge)
    }
}
