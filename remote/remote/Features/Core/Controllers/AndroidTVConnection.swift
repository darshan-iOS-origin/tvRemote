//
//  AndroidTVConnection.swift
//  tvRemoteDemo
//

import Foundation
import Network
import Security

/// The TLS connection to a TV's pairing port (6467) or control port (6466). The protocol is the seam
/// a fake TV can replace.
nonisolated protocol AndroidTVPairingConnection: Sendable {
    /// Opens the TLS connection. Throws `PairingError.unreachable` or `.timedOut`.
    func connect(timeout: TimeInterval) async throws
    func send(_ data: Data) async throws

    /// The next chunk of bytes from the TV. Throws `.timedOut` if none arrives in time, and
    /// `.unreachable` if the TV closes the connection. A nil `timeout` waits for as long as it takes,
    /// which is what a connection that only listens for pings needs.
    func receive(timeout: TimeInterval?) async throws -> Data

    /// The TV's RSA public key as PKCS#1 DER, taken from its certificate during the TLS handshake.
    /// The pairing secret is hashed from it. Nil before the handshake, or for a non-RSA key.
    var serverPublicKey: Data? { get }

    /// The TV's whole certificate (DER), kept so its MAC address can be read for Wake-on-LAN.
    var serverCertificate: Data? { get }

    func close()
}

nonisolated extension AndroidTVPairingConnection {
    var serverCertificate: Data? { nil }
}

nonisolated protocol AndroidTVConnectionMaking: Sendable {
    /// Throws `PairingError` (`.unreachable` for an address we must not talk to,
    /// `.identityUnavailable` when the phone cannot make its client certificate).
    func makeConnection(host: String, port: UInt16) throws -> AndroidTVPairingConnection
}

nonisolated struct NWAndroidTVConnector: AndroidTVConnectionMaking {
    private let identityProvider: ClientIdentityProviding

    init(identityProvider: ClientIdentityProviding = KeychainClientIdentity()) {
        self.identityProvider = identityProvider
    }

    func makeConnection(host: String, port: UInt16) throws -> AndroidTVPairingConnection {
        // The TV's certificate is self-signed, so it cannot be checked. That is only acceptable on
        // the local network (CLAUDE.md, Networking).
        guard LocalTrustPolicy.shouldTrust(host: host),
              let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw PairingError.unreachable
        }

        let identity: SecIdentity
        do {
            identity = try identityProvider.identity()
        } catch {
            throw PairingError.identityUnavailable
        }
        guard let secIdentity = sec_identity_create(identity) else {
            throw PairingError.identityUnavailable
        }

        let queue = DispatchQueue(label: "tvremote.androidtv.tls")
        let serverKey = ServerKeyBox()
        let tls = NWProtocolTLS.Options()
        // The TV's certificate is self-signed, so every server certificate is accepted here. The
        // address check above is what limits this to the local network. The certificate's key is
        // kept, because the pairing secret is hashed from it.
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
            serverKey.store(from: sec_trust_copy_ref(trust).takeRetainedValue())
            complete(true)
        }, queue)
        sec_protocol_options_set_challenge_block(tls.securityProtocolOptions, { _, complete in
            complete(secIdentity)
        }, queue)

        let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        #if DEBUG
        // The iOS Simulator uses the Mac's network, which can be wired. Never cellular.
        parameters.prohibitedInterfaceTypes = [.cellular]
        #else
        parameters.requiredInterfaceType = .wifi
        #endif
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
        return NWAndroidTVConnection(connection: connection, serverKey: serverKey)
    }
}

/// The TV's public key, set once by the TLS verify block and read later. Safe across threads.
private nonisolated final class ServerKeyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var key: Data?
    private var certificate: Data?

    var value: Data? {
        lock.lock()
        defer { lock.unlock() }
        return key
    }

    var certificateValue: Data? {
        lock.lock()
        defer { lock.unlock() }
        return certificate
    }

    func store(from trust: SecTrust) {
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let first = chain.first {
            lock.lock()
            certificate = SecCertificateCopyData(first) as Data
            lock.unlock()
        }
        guard let publicKey = SecTrustCopyKey(trust),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return
        }
        lock.lock()
        key = data
        lock.unlock()
    }
}

/// A result that is delivered once, to whoever waits for it, whether it arrives before or after the
/// wait starts. Safe to resolve from any thread and any number of times: only the first counts.
private nonisolated final class OneShot<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: Result<Value, PairingError>?
    private var waiter: CheckedContinuation<Value, Error>?

    func resolve(_ result: Result<Value, PairingError>) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        outcome = result
        let pending = waiter
        waiter = nil
        lock.unlock()
        pending?.resume(with: result.mapError { $0 as Error })
    }

    /// Waits for the result. If the waiting task is cancelled, the wait ends with an error.
    func wait() async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value, Error>) in
                self.install(continuation)
            }
        } onCancel: {
            self.resolve(.failure(.unreachable))
        }
    }

    private func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let outcome {
            lock.unlock()
            continuation.resume(with: outcome.mapError { $0 as Error })
        } else {
            waiter = continuation
            lock.unlock()
        }
    }
}

nonisolated final class NWAndroidTVConnection: AndroidTVPairingConnection, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "tvremote.androidtv.pairing")
    private let ready = OneShot<Void>()
    private let serverKey: ServerKeyBox

    fileprivate init(connection: NWConnection, serverKey: ServerKeyBox) {
        self.connection = connection
        self.serverKey = serverKey
    }

    var serverPublicKey: Data? {
        serverKey.value
    }

    var serverCertificate: Data? {
        serverKey.certificateValue
    }

    func connect(timeout: TimeInterval) async throws {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.ready.resolve(.success(()))
            case .waiting, .failed, .cancelled:
                self?.ready.resolve(.failure(.unreachable))
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.ready.resolve(.failure(.timedOut))
        }
        try await ready.wait()
    }

    func send(_ data: Data) async throws {
        let sent = OneShot<Void>()
        connection.send(content: data, completion: .contentProcessed { error in
            sent.resolve(error == nil ? .success(()) : .failure(.unreachable))
        })
        try await sent.wait()
    }

    func receive(timeout: TimeInterval?) async throws -> Data {
        let received = OneShot<Data>()
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            if let data, !data.isEmpty {
                received.resolve(.success(data))
            } else {
                // The TV closed the connection, or the read failed.
                received.resolve(.failure(.unreachable))
            }
        }
        if let timeout {
            queue.asyncAfter(deadline: .now() + timeout) {
                received.resolve(.failure(.timedOut))
            }
        }
        return try await received.wait()
    }

    func close() {
        connection.stateUpdateHandler = nil
        connection.cancel()
    }
}
