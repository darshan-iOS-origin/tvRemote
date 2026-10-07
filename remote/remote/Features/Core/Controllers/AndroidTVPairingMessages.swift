//
//  AndroidTVPairingMessages.swift
//  tvRemoteDemo
//
//  The Android / Google TV pairing messages ("polo", protocol version 2), first half: everything up
//  to the moment the TV shows its 6-character code. Sending the code is not built yet.
//
//  Layout source: the "Google TV (aka Android TV) Remote Control (v2)" wiki page of
//  Aymkdn/assistant-freebox-cloud, which odyshewroman/AndroidTVRemoteControl (MIT) also follows.
//  Every message is a varint length followed by a protobuf message. Nothing is copied from either
//  project. The bytes are rebuilt here and the tests check them against the wiki's examples.
//
//  Note on the wiki: its example pairing request says the inner length is 43, but the bytes it lists
//  add up to 38 (and to its own total of 45). The lengths here are computed, not copied.
//

import CryptoKit
import Foundation

/// Writes the few protobuf field types this protocol uses. No protobuf library is needed.
nonisolated struct ProtoWriter {
    private(set) var bytes: [UInt8] = []

    static func varintBytes(_ value: UInt64) -> [UInt8] {
        var remaining = value
        var result: [UInt8] = []
        while remaining >= 0x80 {
            result.append(UInt8(remaining & 0x7F) | 0x80)
            remaining >>= 7
        }
        result.append(UInt8(remaining))
        return result
    }

    /// A varint field (wire type 0).
    mutating func varint(field: Int, _ value: Int) {
        bytes += Self.varintBytes(UInt64(field << 3))
        bytes += Self.varintBytes(UInt64(value))
    }

    /// A length-delimited field (wire type 2): a nested message, bytes or a string.
    mutating func message(field: Int, _ payload: [UInt8]) {
        bytes += Self.varintBytes(UInt64((field << 3) | 2))
        bytes += Self.varintBytes(UInt64(payload.count))
        bytes += payload
    }

    mutating func string(field: Int, _ text: String) {
        message(field: field, Array(text.utf8))
    }
}

nonisolated struct ProtoField: Equatable {
    enum Value: Equatable {
        case varint(UInt64)
        case bytes([UInt8])
    }

    var number: Int
    var value: Value

    var varintValue: UInt64? {
        if case .varint(let number) = value { return number }
        return nil
    }
}

/// Reads the top-level fields of a protobuf message. Fixed-size fields are skipped.
nonisolated enum ProtoReader {
    /// Nil when the bytes are not a well-formed message.
    static func fields(in bytes: [UInt8]) -> [ProtoField]? {
        var fields: [ProtoField] = []
        var index = 0

        func readVarint() -> UInt64? {
            var result: UInt64 = 0
            var shift: UInt64 = 0
            while index < bytes.count, shift < 64 {
                let byte = bytes[index]
                index += 1
                result |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return result }
                shift += 7
            }
            return nil
        }

        while index < bytes.count {
            guard let tag = readVarint() else { return nil }
            let number = Int(tag >> 3)
            switch tag & 0x07 {
            case 0:
                guard let value = readVarint() else { return nil }
                fields.append(ProtoField(number: number, value: .varint(value)))
            case 2:
                guard let count = readVarint(), count <= UInt64(bytes.count - index) else { return nil }
                let end = index + Int(count)
                fields.append(ProtoField(number: number, value: .bytes(Array(bytes[index..<end]))))
                index = end
            case 1:
                guard bytes.count - index >= 8 else { return nil }
                index += 8
            case 5:
                guard bytes.count - index >= 4 else { return nil }
                index += 4
            default:
                return nil
            }
        }
        return fields
    }
}

/// Collects the chunks the TV sends and cuts them into frames (a varint length, then that many bytes).
nonisolated struct PairingFrameBuffer {
    private var bytes: [UInt8] = []

    mutating func append(_ data: Data) {
        bytes.append(contentsOf: data)
    }

    /// The next complete frame's payload, or nil if more data is needed.
    mutating func nextFrame() -> [UInt8]? {
        var length = 0
        var shift = 0
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            length |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                guard bytes.count - index >= length else { return nil }
                let frame = Array(bytes[index..<(index + length)])
                bytes.removeFirst(index + length)
                return frame
            }
            shift += 7
            if shift >= 35 {
                // Not a length we could ever receive. Drop the data instead of waiting forever.
                bytes.removeAll()
                return nil
            }
        }
        return nil
    }
}

nonisolated enum AndroidTVPairingMessages {
    static let protocolVersion = 2
    /// `STATUS_OK` in the protocol. The TV answers 400 (error) or 401 (bad configuration) otherwise.
    static let statusOK = 200

    /// The field number of each message's payload inside the envelope.
    enum PayloadField: Int {
        case pairingRequest = 10
        case pairingRequestAck = 11
        case option = 20
        case configuration = 30
        case configurationAck = 31
        case secret = 40
        case secretAck = 41
    }

    private static let hexadecimalEncoding = 3
    private static let symbolLength = 6
    private static let inputRole = 1

    // MARK: - What we send

    static func pairingRequest(serviceName: String, clientName: String) -> Data {
        var request = ProtoWriter()
        request.string(field: 1, serviceName)
        request.string(field: 2, clientName)
        return frame(envelope(.pairingRequest, request.bytes))
    }

    /// We can enter a code of 6 hexadecimal characters.
    static func option() -> Data {
        var payload = ProtoWriter()
        payload.message(field: 1, encoding())
        payload.varint(field: 3, inputRole)
        return frame(envelope(.option, payload.bytes))
    }

    static func configuration() -> Data {
        var payload = ProtoWriter()
        payload.message(field: 1, encoding())
        payload.varint(field: 2, inputRole)
        return frame(envelope(.configuration, payload.bytes))
    }

    /// The encoded secret: the 32-byte hash from `AndroidTVPairingSecret`, sent once the user has
    /// typed the code. On the wire: `42, 8,2, 16,200,1, 194,2, 34, 10, 32, <hash>`.
    static func secret(_ hash: [UInt8]) -> Data {
        var payload = ProtoWriter()
        payload.message(field: 1, hash)
        return frame(envelope(.secret, payload.bytes))
    }

    // MARK: - What we accept

    /// Checks one message from the TV: the status must be OK and the expected payload must be there.
    /// - Throws: `.rejected` for a refusal, `.badResponse` for anything we cannot read.
    static func validate(_ message: [UInt8], expecting expected: PayloadField) throws {
        guard let fields = ProtoReader.fields(in: message),
              let status = fields.first(where: { $0.number == 2 })?.varintValue else {
            throw PairingError.badResponse
        }
        guard status == UInt64(statusOK) else {
            throw PairingError.rejected
        }
        guard fields.contains(where: { $0.number == expected.rawValue }) else {
            throw PairingError.badResponse
        }
    }

    // MARK: - Building blocks

    private static func encoding() -> [UInt8] {
        var encoding = ProtoWriter()
        encoding.varint(field: 1, hexadecimalEncoding)
        encoding.varint(field: 2, symbolLength)
        return encoding.bytes
    }

    private static func envelope(_ field: PayloadField, _ payload: [UInt8]) -> [UInt8] {
        var envelope = ProtoWriter()
        envelope.varint(field: 1, protocolVersion)
        envelope.varint(field: 2, statusOK)
        envelope.message(field: field.rawValue, payload)
        return envelope.bytes
    }

    /// A varint length, then the message. Every message in this protocol is framed this way.
    static func frame(_ message: [UInt8]) -> Data {
        Data(ProtoWriter.varintBytes(UInt64(message.count)) + message)
    }
}

/// The encoded secret that proves the code was typed correctly. From the protocol wiki:
///   SHA-256 over: client modulus, client exponent, server modulus, server exponent, and the last
///   2 bytes of the code (its last 4 hexadecimal characters). Leading zero bytes are removed from
///   each number first.
/// The code's first byte must equal the first byte of that hash, so the phone can tell a mistyped
/// code before it sends anything.
nonisolated enum AndroidTVPairingSecret {
    /// The hash for a well-formed code, or nil when `code` is not 6 hexadecimal characters.
    static func hash(client: RSAPublicKeyComponents, server: RSAPublicKeyComponents, code: String) -> (hash: [UInt8], firstCodeByte: UInt8)? {
        let normalized = PairingCodeFormat.androidTV.normalized(code)
        guard normalized.count == 6,
              let first = UInt8(normalized.prefix(2), radix: 16),
              let second = UInt8(normalized.dropFirst(2).prefix(2), radix: 16),
              let third = UInt8(normalized.suffix(2), radix: 16) else {
            return nil
        }

        var sha = SHA256()
        sha.update(data: client.modulus)
        sha.update(data: client.exponent)
        sha.update(data: server.modulus)
        sha.update(data: server.exponent)
        sha.update(data: [second, third])
        return (Array(sha.finalize()), first)
    }
}
