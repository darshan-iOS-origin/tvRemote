//
//  TokenStore.swift
//  tvRemoteDemo
//

import Foundation
import Security

/// Where a TV's pairing token is kept so the next connection shows no prompt on the TV.
nonisolated protocol TVTokenStoring: Sendable {
    func token(for host: String, platform: TVPlatform) -> String?
    func save(_ token: String, for host: String, platform: TVPlatform)
    func remove(for host: String, platform: TVPlatform)
}

/// Keychain storage, as CLAUDE.md asks. One entry per platform and TV address. The token never
/// leaves this phone's Keychain (no iCloud sync) and is never logged.
nonisolated struct KeychainTokenStore: TVTokenStoring {
    private let service: String

    init(service: String = "com.iOS.tvRemoteDemo.tvtoken") {
        self.service = service
    }

    func token(for host: String, platform: TVPlatform) -> String? {
        var query = baseQuery(host: host, platform: platform)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String, for host: String, platform: TVPlatform) {
        let query = baseQuery(host: host, platform: platform)
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    /// Deletes a TV's token, so forgetting a TV leaves nothing of it in the Keychain.
    func remove(for host: String, platform: TVPlatform) {
        _ = SecItemDelete(baseQuery(host: host, platform: platform) as CFDictionary)
    }

    private func baseQuery(host: String, platform: TVPlatform) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(platform.rawValue)@\(host)"
        ]
    }
}
