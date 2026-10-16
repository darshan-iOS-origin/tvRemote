//
//  FavoriteStore.swift
//  tvRemoteDemo
//

import Foundation

/// An app or a channel the user saved for one tap access.
nonisolated struct Favorite: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case app
        case channel
    }

    var id: UUID
    var kind: Kind
    var name: String
    /// An app's id (whatever that TV's platform needs to open it), or a channel number such as `5` or `7.1`.
    var value: String

    init(kind: Kind, name: String, value: String) {
        self.id = UUID()
        self.kind = kind
        self.name = name
        self.value = value
    }

    var subtitle: String {
        switch kind {
        case .app: return "App"
        case .channel: return "Channel \(value)"
        }
    }

    var symbolName: String {
        switch kind {
        case .app: return "square.grid.2x2.fill"
        case .channel: return "tv"
        }
    }
}

/// What counts as a channel number: digits, with an optional `.` or `-` and more digits for a
/// sub-channel (`7.1`). Short, so it can never carry anything else to a TV.
nonisolated enum ChannelNumber {
    static func isValid(_ text: String) -> Bool {
        guard text.count <= 8, !text.isEmpty else { return false }
        let parts = text.split(omittingEmptySubsequences: false) { $0 == "." || $0 == "-" }
        guard parts.count <= 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { ("0"..."9").contains($0) } }) else {
            return false
        }
        // At most one separator.
        return text.filter { $0 == "." || $0 == "-" }.count == parts.count - 1
    }
}

/// Where favorites are kept: one list per TV. Nothing secret is stored.
nonisolated protocol FavoriteStoring: Sendable {
    func favorites(for host: String) -> [Favorite]

    /// Adds a favorite, unless the same app or channel is already there.
    func add(_ favorite: Favorite, for host: String)

    /// Replaces the whole list, for removing and reordering.
    func replace(_ list: [Favorite], for host: String)

    /// Moves a TV's favorites to its new address.
    func move(from oldHost: String, to newHost: String)

    /// Deletes a TV's favorites.
    func clear(for host: String)
}

/// JSON in `UserDefaults`, one key per TV address. Favorites follow the address, not the TV: a TV that
/// gets a new address from the router starts with an empty list.
nonisolated struct UserDefaultsFavoriteStore: FavoriteStoring {
    private static func key(for host: String) -> String {
        "favorites." + host
    }

    func favorites(for host: String) -> [Favorite] {
        guard let data = UserDefaults.standard.data(forKey: Self.key(for: host)),
              let list = try? JSONDecoder().decode([Favorite].self, from: data) else {
            return []
        }
        return list
    }

    func add(_ favorite: Favorite, for host: String) {
        var list = favorites(for: host)
        guard !list.contains(where: { $0.kind == favorite.kind && $0.value == favorite.value }) else { return }
        list.append(favorite)
        replace(list, for: host)
    }

    func move(from oldHost: String, to newHost: String) {
        guard oldHost != newHost else { return }
        var merged = favorites(for: newHost)
        for favorite in favorites(for: oldHost) where !merged.contains(where: { $0.kind == favorite.kind && $0.value == favorite.value }) {
            merged.append(favorite)
        }
        replace(merged, for: newHost)
        clear(for: oldHost)
    }

    func clear(for host: String) {
        UserDefaults.standard.removeObject(forKey: Self.key(for: host))
    }

    func replace(_ list: [Favorite], for host: String) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: Self.key(for: host))
    }
}
