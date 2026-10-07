//
//  GoogleCastMessages.swift
//  tvRemoteDemo
//
//  The Google Cast (CASTV2) messages, as in pychromecast (MIT, `socket_client.py`) and
//  `cast_channel.proto`. Each message on the wire is a 4-byte big-endian length followed by a
//  `CastMessage` protobuf:
//    1 protocol_version (always 0)   2 source_id   3 destination_id   4 namespace
//    5 payload_type (0 = text)       6 payload_utf8 (JSON)
//  No code is copied.
//

import Foundation

/// A message from the TV.
nonisolated struct CastIncoming: Sendable {
    var source: String
    var destination: String
    var namespace: String
    /// The JSON text of the payload.
    var payload: String

    /// The payload as a dictionary, or nil if it is not JSON.
    var object: [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any]
    }

    var type: String? {
        object?["type"] as? String
    }
}

nonisolated enum GoogleCastMessages {
    static let senderID = "sender-0"
    /// The TV itself, as opposed to an app running on it.
    static let platformID = "receiver-0"

    static let connectionNamespace = "urn:x-cast:com.google.cast.tp.connection"
    static let heartbeatNamespace = "urn:x-cast:com.google.cast.tp.heartbeat"
    static let receiverNamespace = "urn:x-cast:com.google.cast.receiver"
    static let mediaNamespace = "urn:x-cast:com.google.cast.media"

    /// The Default Media Receiver: the TV's built-in player for photos, video and audio from an address.
    static let defaultMediaReceiver = "CC1AD845"

    /// A message ready to send, or nil if the payload cannot be written as JSON.
    static func frame(destination: String, namespace: String, payload: [String: Any]) -> Data? {
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }
        var message = ProtoWriter()
        message.varint(field: 1, 0)
        message.string(field: 2, senderID)
        message.string(field: 3, destination)
        message.string(field: 4, namespace)
        message.varint(field: 5, 0)
        message.string(field: 6, String(decoding: json, as: UTF8.self))

        let length = UInt32(message.bytes.count)
        let prefix: [UInt8] = [UInt8(length >> 24), UInt8((length >> 16) & 0xFF), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        return Data(prefix + message.bytes)
    }

    /// Takes every complete message out of `buffer`, leaving any partial one in place.
    static func decode(_ buffer: inout [UInt8]) -> [CastIncoming] {
        var messages: [CastIncoming] = []
        while buffer.count >= 4 {
            let length = Int(buffer[0]) << 24 | Int(buffer[1]) << 16 | Int(buffer[2]) << 8 | Int(buffer[3])
            // A message is small. A huge length means the stream is not what we expect.
            guard length <= 1 << 20 else {
                buffer.removeAll()
                break
            }
            guard buffer.count >= 4 + length else { break }
            let body = Array(buffer[4 ..< 4 + length])
            buffer.removeFirst(4 + length)

            guard let fields = ProtoReader.fields(in: body) else { continue }
            func text(_ number: Int) -> String {
                guard let field = fields.first(where: { $0.number == number }), case .bytes(let bytes) = field.value else {
                    return ""
                }
                return String(decoding: bytes, as: UTF8.self)
            }
            messages.append(CastIncoming(source: text(2), destination: text(3), namespace: text(4), payload: text(6)))
        }
        return messages
    }
}
