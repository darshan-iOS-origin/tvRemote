//
//  SelfSignedCertificate.swift
//  tvRemoteDemo
//
//  iOS can create an RSA key but has no API to issue a certificate, so the small self-signed
//  certificate that Android / Google TV wants from a client is written out by hand in DER.
//  The byte layout was checked offline: a Python builder with the same layout produced
//  certificates that `openssl x509` parses and whose signature `openssl verify` accepts.
//

import Foundation

/// The few ASN.1 DER pieces an X.509 certificate needs.
nonisolated enum DER {
    static let null: [UInt8] = [0x05, 0x00]

    static func length(_ count: Int) -> [UInt8] {
        if count < 0x80 {
            return [UInt8(count)]
        }
        var bytes: [UInt8] = []
        var value = count
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [UInt8(0x80 | bytes.count)] + bytes
    }

    static func element(tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag] + length(content.count) + content
    }

    static func sequence(_ parts: [[UInt8]]) -> [UInt8] {
        element(tag: 0x30, Array(parts.joined()))
    }

    static func set(_ parts: [[UInt8]]) -> [UInt8] {
        element(tag: 0x31, Array(parts.joined()))
    }

    /// A non-negative INTEGER. `bytes` must have no redundant leading zero.
    static func integer(_ bytes: [UInt8]) -> [UInt8] {
        let needsPadding = (bytes.first ?? 0) & 0x80 != 0
        return element(tag: 0x02, needsPadding ? [0x00] + bytes : bytes)
    }

    static func objectIdentifier(_ encoded: [UInt8]) -> [UInt8] {
        element(tag: 0x06, encoded)
    }

    static func utf8String(_ text: String) -> [UInt8] {
        element(tag: 0x0C, Array(text.utf8))
    }

    /// UTCTime as `YYMMDDHHMMSSZ`. Valid for years up to 2049.
    static func utcTime(_ date: Date) -> [UInt8] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let fields = [(parts.year ?? 0) % 100, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0]
        let text = fields.map { $0 < 10 ? "0\($0)" : "\($0)" }.joined() + "Z"
        return element(tag: 0x17, Array(text.utf8))
    }

    static func bitString(_ bytes: [UInt8]) -> [UInt8] {
        element(tag: 0x03, [0x00] + bytes)
    }
}

nonisolated enum SelfSignedCertificate {
    // Object identifiers, DER-encoded without tag and length.
    private static let rsaEncryption: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
    private static let sha256WithRSAEncryption: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]
    private static let commonNameAttribute: [UInt8] = [0x55, 0x04, 0x03]

    /// The part of the certificate that gets signed.
    /// - `publicKey`: the RSA public key as PKCS#1 DER, which is what `SecKeyCopyExternalRepresentation` returns.
    /// - `serial`: 1 to 8 bytes, first byte between 0x01 and 0x7F so the integer needs no padding.
    static func tbsCertificate(
        publicKey: [UInt8],
        commonName: String,
        serial: [UInt8],
        notBefore: Date,
        notAfter: Date
    ) -> [UInt8] {
        let version = DER.element(tag: 0xA0, DER.integer([2]))
        let signatureAlgorithm = algorithm(sha256WithRSAEncryption)
        let name = DER.sequence([DER.set([DER.sequence([
            DER.objectIdentifier(commonNameAttribute),
            DER.utf8String(commonName)
        ])])])
        let validity = DER.sequence([DER.utcTime(notBefore), DER.utcTime(notAfter)])
        let subjectPublicKeyInfo = DER.sequence([algorithm(rsaEncryption), DER.bitString(publicKey)])

        return DER.sequence([
            version,
            DER.integer(serial),
            signatureAlgorithm,
            name,
            validity,
            name,
            subjectPublicKeyInfo
        ])
    }

    /// The finished certificate, from the signed part and its RSA PKCS#1 v1.5 SHA-256 signature.
    static func certificate(tbs: [UInt8], signature: [UInt8]) -> Data {
        Data(DER.sequence([tbs, algorithm(sha256WithRSAEncryption), DER.bitString(signature)]))
    }

    private static func algorithm(_ identifier: [UInt8]) -> [UInt8] {
        DER.sequence([DER.objectIdentifier(identifier), DER.null])
    }
}
