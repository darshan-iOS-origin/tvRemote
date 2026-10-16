import Foundation

/// Finds the TV's own entry for one of the apps on My Apps. TVs name apps differently
/// ("Prime Video", "Amazon Prime Video", "Max", "HBO Max"), so names are compared with only letters
/// and digits, against a few known spellings for each app.
enum AppMatcher {

    private static let aliases: [String: [String]] = [
        "netflix": ["netflix"],
        "jiohotstar": ["jiohotstar", "hotstar", "disneyhotstar"],
        "youtube": ["youtube"],
        "primevideo": ["primevideo", "amazonprimevideo", "amazonvideo", "prime"],
        "paramount": ["paramount", "paramountplus"],
        "hulu": ["hulu"],
        "peacock": ["peacock", "peacocktv"],
        "tubi": ["tubi", "tubitv"],
        "pluto": ["plutotv", "pluto"],
        "max": ["max", "maxtv", "hbomax"]
    ]

    static func match(_ app: StreamingApp, in tvApps: [TVApp]) -> TVApp? {
        let names = Set((aliases[app.id] ?? []) + [normalize(app.name)])
        let candidates = tvApps.map { (app: $0, name: normalize($0.name)) }

        if let exact = candidates.first(where: { names.contains($0.name) }) {
            return exact.app
        }
        // Looser match for longer names only: "max" inside another word would match too much.
        let longNames = names.filter { $0.count >= 5 }
        return candidates.first { candidate in longNames.contains { candidate.name.contains($0) } }?.app
    }

    private static func normalize(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}
