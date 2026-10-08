//
//  ClientIdentity.swift
//  tvRemoteDemo
//

import Foundation
import Security

nonisolated enum ClientIdentityError: Error, Equatable {
    case keyGenerationFailed
    case certificateFailed
    case keychainFailed(OSStatus)
    case notFound
}

/// The TLS client identity (a private key with its certificate) this phone shows to a TV.
nonisolated protocol ClientIdentityProviding: Sendable {
    func identity() throws -> SecIdentity

    /// The identity's RSA public key as PKCS#1 DER. The pairing secret is hashed from it.
    func publicKey() throws -> Data
}

/// One RSA key pair and self-signed certificate per install, kept in the Keychain and created the
/// first time it is needed. It is never shipped with the app: a shared key would let anyone who
/// extracts it control every TV that any user of this app has paired.
///
/// UNVERIFIED on a real device: the Keychain has to join the key and the certificate into an
/// identity by itself (it matches them by the key's hash). If that does not work, `identity()`
/// throws and pairing reports that the certificate could not be created.
nonisolated struct KeychainClientIdentity: ClientIdentityProviding {
    private static let label = "TV Remote Android TV client v2"
    private static let tag = Data("com.iOS.tvRemoteDemo.androidtv.client.v2".utf8)
    private static let accessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    func identity() throws -> SecIdentity {
        if let existing = Self.storedIdentity() {
            return existing
        }
        try Self.createIdentity()
        guard let created = Self.storedIdentity() else {
            throw ClientIdentityError.notFound
        }
        return created
    }

    func publicKey() throws -> Data {
        let stored = try self.identity()
        var found: SecCertificate?
        guard SecIdentityCopyCertificate(stored, &found) == errSecSuccess,
              let certificate = found,
              let key = SecCertificateCopyKey(certificate),
              let data = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            throw ClientIdentityError.notFound
        }
        // For an RSA key, the external representation is the PKCS#1 public key.
        return data
    }

    private static func storedIdentity() -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let found = item,
              CFGetTypeID(found) == SecIdentityGetTypeID() else {
            return nil
        }
        return unsafeBitCast(found, to: SecIdentity.self)
    }

    private static func createIdentity() throws {
        // Remove anything left by an earlier attempt that stopped half way.
        _ = SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: tag] as CFDictionary)
        _ = SecItemDelete([kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: label] as CFDictionary)

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrLabel as String: label,
                kSecAttrAccessible as String: accessible
            ] as [String: Any]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw ClientIdentityError.keyGenerationFailed
        }

        // For an RSA key, the external representation is the PKCS#1 public key.
        let now = Date()
        let tbs = SelfSignedCertificate.tbsCertificate(
            publicKey: Array(publicKeyData),
            commonName: "atvremote",
            serial: randomSerial(),
            // Valid from 2020, not from yesterday: a TV or emulator with a wrong clock would otherwise
            // see the certificate as "not valid yet" and refuse it on the control port.
            notBefore: Date(timeIntervalSince1970: 1_577_836_800),
            notAfter: now.addingTimeInterval(20 * 365 * 24 * 60 * 60)
        )
        guard let signature = SecKeyCreateSignature(
            privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(tbs) as CFData, &error
        ) as Data? else {
            throw ClientIdentityError.certificateFailed
        }
        let der = SelfSignedCertificate.certificate(tbs: tbs, signature: Array(signature))
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw ClientIdentityError.certificateFailed
        }

        let status = SecItemAdd([
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: label,
            kSecAttrAccessible as String: accessible
        ] as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ClientIdentityError.keychainFailed(status)
        }
    }

    /// Eight random bytes whose first byte is 1 to 127, so the DER integer needs no padding.
    private static func randomSerial() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        bytes[0] = bytes[0] % 0x7F + 1
        return bytes
    }
}
