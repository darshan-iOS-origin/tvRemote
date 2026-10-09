//
//  AndroidTVPairing.swift
//  tvRemoteDemo
//
//  Android / Google TV pairing.
//    start:   TLS on port 6467 with a client certificate
//             -> pairing request  <- ack
//             -> option           <- option
//             -> configuration    <- configuration ack      (the TV now shows the code)
//    submit:  hash the code with both public keys, check its first byte against the code,
//             -> secret           <- secret ack             (this phone is now paired)
//  Message layout: see AndroidTVPairingMessages.swift.
//
//  The TV expects the code on the same connection, so the connection is kept open, keyed by the
//  challenge, until the code is accepted or the user gives up (`cancel`). Pairing is remembered by
//  the TV against this phone's client certificate, so nothing needs to be stored here.
//

import Foundation

/// The open pairing connections, by challenge token.
actor AndroidTVPairingSessions {
    private var connections: [String: AndroidTVPairingConnection] = [:]

    func store(_ connection: AndroidTVPairingConnection, id: String) {
        connections[id] = connection
    }

    /// The connection for a challenge, left in place so a mistyped code can be retried.
    func peek(id: String) -> AndroidTVPairingConnection? {
        connections[id]
    }

    func take(id: String) -> AndroidTVPairingConnection? {
        connections.removeValue(forKey: id)
    }
}

nonisolated struct AndroidTVPairing: TVPairing {
    let platform = TVPlatform.androidTV

    /// The pairing port. Source: the protocol wiki and AndroidTVRemoteControl (see the messages file).
    static let pairingPort: UInt16 = 6467

    /// The service name sent to the TV. The wiki's example uses an arbitrary reverse-domain name.
    /// UNVERIFIED: whether every TV accepts any name.
    static let serviceName = "com.tvremote.universal.smartcontrol"

    /// The name the TV shows for this phone.
    static let clientName = "TV Remote"

    private let connector: AndroidTVConnectionMaking
    private let identityProvider: ClientIdentityProviding
    private let sessions: AndroidTVPairingSessions
    private let connectTimeout: TimeInterval
    private let replyTimeout: TimeInterval

    init(
        connector: AndroidTVConnectionMaking = NWAndroidTVConnector(),
        identityProvider: ClientIdentityProviding = KeychainClientIdentity(),
        sessions: AndroidTVPairingSessions = AndroidTVPairingSessions(),
        connectTimeout: TimeInterval = 10,
        replyTimeout: TimeInterval = 10
    ) {
        self.connector = connector
        self.identityProvider = identityProvider
        self.sessions = sessions
        self.connectTimeout = connectTimeout
        self.replyTimeout = replyTimeout
    }

    func start(device: TVDevice) async throws -> PairingChallenge {
        let connection: AndroidTVPairingConnection
        do {
            connection = try connector.makeConnection(host: device.host, port: Self.pairingPort)
        } catch {
            throw (error as? PairingError) ?? PairingError.unreachable
        }

        do {
            try await connection.connect(timeout: connectTimeout)
            try await handshake(over: connection)
        } catch {
            connection.close()
            throw (error as? PairingError) ?? PairingError.unreachable
        }

        let id = UUID().uuidString
        await sessions.store(connection, id: id)
        return PairingChallenge(platform: .androidTV, token: id, deviceID: "", port: Self.pairingPort)
    }

    func cancel(_ challenge: PairingChallenge) async {
        await sessions.take(id: challenge.token)?.close()
    }

    /// Sends the code. A mistyped code is caught here, before anything is sent, and the connection
    /// stays open so the user can type it again.
    func submit(code: String, challenge: PairingChallenge) async throws {
        guard let connection = await sessions.peek(id: challenge.token) else {
            // The connection is gone (closed by the TV, or by cancel). Pairing has to start again.
            throw PairingError.unreachable
        }

        guard let serverData = connection.serverPublicKey,
              let server = RSAPublicKey.components(fromPKCS1: Array(serverData)) else {
            throw PairingError.badResponse
        }
        let clientData: Data
        do {
            clientData = try identityProvider.publicKey()
        } catch {
            throw PairingError.identityUnavailable
        }
        guard let client = RSAPublicKey.components(fromPKCS1: Array(clientData)) else {
            throw PairingError.identityUnavailable
        }
        guard let secret = AndroidTVPairingSecret.hash(client: client, server: server, code: code) else {
            throw PairingError.wrongCode
        }
        guard secret.hash.first == secret.firstCodeByte else {
            throw PairingError.wrongCode
        }

        do {
            try await connection.send(AndroidTVPairingMessages.secret(secret.hash))
            try await validateSecretAck(over: connection)
        } catch {
            _ = await sessions.take(id: challenge.token)
            connection.close()
            throw (error as? PairingError) ?? PairingError.unreachable
        }

        // Paired. The TV has stored this phone's certificate, so the connection is no longer needed.
        _ = await sessions.take(id: challenge.token)
        connection.close()
    }

    private func validateSecretAck(over connection: AndroidTVPairingConnection) async throws {
        var buffer = PairingFrameBuffer()
        while true {
            if let frame = buffer.nextFrame() {
                try AndroidTVPairingMessages.validate(frame, expecting: .secretAck)
                return
            }
            let chunk = try await connection.receive(timeout: replyTimeout)
            buffer.append(chunk)
        }
    }

    // MARK: - Handshake

    private func handshake(over connection: AndroidTVPairingConnection) async throws {
        var buffer = PairingFrameBuffer()

        try await exchange(
            AndroidTVPairingMessages.pairingRequest(serviceName: Self.serviceName, clientName: Self.clientName),
            expecting: .pairingRequestAck, over: connection, buffer: &buffer
        )
        try await exchange(
            AndroidTVPairingMessages.option(),
            expecting: .option, over: connection, buffer: &buffer
        )
        try await exchange(
            AndroidTVPairingMessages.configuration(),
            expecting: .configurationAck, over: connection, buffer: &buffer
        )
    }

    /// Sends one message and checks the TV's answer.
    private func exchange(
        _ message: Data,
        expecting expected: AndroidTVPairingMessages.PayloadField,
        over connection: AndroidTVPairingConnection,
        buffer: inout PairingFrameBuffer
    ) async throws {
        try await connection.send(message)
        while true {
            if let frame = buffer.nextFrame() {
                try AndroidTVPairingMessages.validate(frame, expecting: expected)
                return
            }
            let chunk = try await connection.receive(timeout: replyTimeout)
            buffer.append(chunk)
        }
    }
}
