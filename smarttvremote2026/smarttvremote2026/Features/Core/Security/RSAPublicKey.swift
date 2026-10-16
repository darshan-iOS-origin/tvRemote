//
//  RSAPublicKey.swift
//  tvRemoteDemo
//

import Foundation

nonisolated struct RSAPublicKeyComponents: Equatable, Sendable {
    /// Big-endian, with no leading zero bytes.
    var modulus: [UInt8]
    var exponent: [UInt8]
}

nonisolated enum RSAPublicKey {
    /// Reads a PKCS#1 `RSAPublicKey`, which is what `SecKeyCopyExternalRepresentation` returns for
    /// an RSA key: `SEQUENCE { INTEGER modulus, INTEGER publicExponent }`.
    /// Returns nil for anything else (another key type, or damaged data).
    static func components(fromPKCS1 der: [UInt8]) -> RSAPublicKeyComponents? {
        var index = 0

        func readLength() -> Int? {
            guard index < der.count else { return nil }
            let first = der[index]
            index += 1
            if first < 0x80 { return Int(first) }
            let byteCount = Int(first & 0x7F)
            guard byteCount > 0, byteCount <= 4, index + byteCount <= der.count else { return nil }
            var length = 0
            for _ in 0..<byteCount {
                length = (length << 8) | Int(der[index])
                index += 1
            }
            return length
        }

        func readInteger() -> [UInt8]? {
            guard index < der.count, der[index] == 0x02 else { return nil }
            index += 1
            guard let length = readLength(), length > 0, index + length <= der.count else { return nil }
            let value = Array(der[index..<(index + length)])
            index += length
            // A DER integer gets a leading zero when its top bit is set. The protocol hashes
            // the number without it.
            return Array(value.drop(while: { $0 == 0 }))
        }

        guard index < der.count, der[index] == 0x30 else { return nil }
        index += 1
        guard let sequenceLength = readLength(), index + sequenceLength == der.count,
              let modulus = readInteger(), let exponent = readInteger(),
              index == der.count, !modulus.isEmpty, !exponent.isEmpty else {
            return nil
        }
        return RSAPublicKeyComponents(modulus: modulus, exponent: exponent)
    }
}
