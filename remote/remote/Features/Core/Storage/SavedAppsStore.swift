import Foundation

/// Keeps the ids of the apps the user added to "My Apps", in display order.
protocol SavedAppsStoring {
    func load() -> [String]
    func save(_ ids: [String])
}

struct UserDefaultsSavedAppsStore: SavedAppsStoring {

    private let defaults: UserDefaults
    private let key = "savedAppIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func save(_ ids: [String]) {
        defaults.set(ids, forKey: key)
    }
}

enum SavedAppsStore {
    static let shared: SavedAppsStoring = UserDefaultsSavedAppsStore()
}
