//
//  DeviceStore.swift
//  tvRemoteDemo
//

import Foundation

/// A TV the user has connected to. Only what is needed to open its remote again. The raw details read
/// during discovery (serial numbers, MAC addresses) are never saved.
nonisolated struct SavedTV: Codable, Hashable, Sendable {
    var id: String
    var name: String
    var brand: String
    var platform: String
    var host: String
    var modelName: String?
    /// A name the user chose. Optional, so TVs saved by earlier versions still load.
    var nickname: String?
    var lastConnected: Date?
    /// The TV the launch screen offers to open with one tap. At most one TV has it.
    var isDefault: Bool?
    /// Shown on the Favourites tab. Optional, so TVs saved by earlier versions still load.
    var isFavorite: Bool?

    init(_ device: TVDevice) {
        self.id = device.id
        self.name = device.name
        self.brand = device.brand.rawValue
        self.platform = device.platform.rawValue
        self.host = device.host
        self.modelName = device.modelName
    }

    /// The TV as the rest of the app sees it: shown under its nickname when it has one.
    var device: TVDevice {
        TVDevice(
            id: id,
            name: (nickname?.isEmpty == false ? nickname : nil) ?? name,
            brand: TVBrand(rawValue: brand) ?? .unknown,
            platform: TVPlatform(rawValue: platform) ?? .unknown,
            host: host,
            modelName: modelName
        )
    }
}

/// Where the user's TVs are kept between launches. Pairing tokens do not go here: they go in the
/// Keychain (`TokenStore`).
nonisolated protocol DeviceStoring: Sendable {
    func load() -> [SavedTV]

    /// Adds the TV, or replaces the saved one with the same address or the same real id.
    func save(_ device: TVDevice)

    func remove(host: String)

    /// A saved TV that a scan finds at a new address (the router gave it a new one) follows it.
    /// Returns the address it had before, or nil if nothing changed. An id equal to the address is
    /// not a real id.
    @discardableResult
    func updateHost(from scanned: TVDevice) -> String?

    /// Gives the TV a name of the user's choosing. Nil or empty goes back to the TV's own name.
    func rename(host: String, to nickname: String?)

    /// Makes this TV the default, and no other.
    func setDefault(host: String, isDefault: Bool)

    /// Adds the TV to the Favourites tab, or takes it off.
    func setFavorite(host: String, isFavorite: Bool)

    /// Saves the list in this order. Used after the user reorders it.
    func reorder(_ list: [SavedTV])
}

/// JSON in `UserDefaults`. The list holds names and local addresses, nothing secret.
nonisolated struct UserDefaultsDeviceStore: DeviceStoring {
    private static let key = "savedTVs"

    func load() -> [SavedTV] {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let list = try? JSONDecoder().decode([SavedTV].self, from: data) else {
            return []
        }
        return list
    }

    func save(_ device: TVDevice) {
        var list = load()
        var new = SavedTV(device)
        new.lastConnected = Date()
        if let index = list.firstIndex(where: { Self.isSame($0, new) }) {
            // Keep what the user set. A TV opened under its nickname must not save the nickname as its name.
            let existing = list[index]
            new.nickname = existing.nickname
            new.isDefault = existing.isDefault
            new.isFavorite = existing.isFavorite
            if let nickname = existing.nickname, new.name == nickname {
                new.name = existing.name
            }
            list[index] = new
        } else {
            list.append(new)
        }
        write(list)
    }

    func remove(host: String) {
        write(load().filter { $0.host != host })
    }

    @discardableResult
    func updateHost(from scanned: TVDevice) -> String? {
        guard scanned.id != scanned.host else { return nil }
        var list = load()
        guard let index = list.firstIndex(where: { $0.id == scanned.id && $0.host != scanned.host }) else {
            return nil
        }
        let previous = list[index].host
        list[index].host = scanned.host
        write(list)
        return previous
    }

    func rename(host: String, to nickname: String?) {
        var list = load()
        guard let index = list.firstIndex(where: { $0.host == host }) else { return }
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        list[index].nickname = (trimmed?.isEmpty == false) ? trimmed : nil
        write(list)
    }

    func setDefault(host: String, isDefault: Bool) {
        var list = load()
        for index in list.indices {
            list[index].isDefault = (isDefault && list[index].host == host) ? true : nil
        }
        write(list)
    }

    func setFavorite(host: String, isFavorite: Bool) {
        var list = load()
        guard let index = list.firstIndex(where: { $0.host == host }) else { return }
        list[index].isFavorite = isFavorite ? true : nil
        write(list)
    }

    func reorder(_ list: [SavedTV]) {
        write(list)
    }

    private static func isSame(_ saved: SavedTV, _ other: SavedTV) -> Bool {
        saved.host == other.host || (saved.id != saved.host && saved.id == other.id)
    }

    private func write(_ list: [SavedTV]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
