import Foundation

/// A streaming app the user can add to "My Apps". `imageName` is an asset in `Assets.xcassets/apps`.
struct StreamingApp: Identifiable, Hashable {
    let id: String
    let name: String
    let imageName: String

    /// Every app that can be added, in list order.
    static let catalog: [StreamingApp] = [
        StreamingApp(id: "netflix", name: "Netflix", imageName: "netflix"),
        StreamingApp(id: "jiohotstar", name: "JioHotstar", imageName: "jiohotstar"),
        StreamingApp(id: "youtube", name: "YouTube", imageName: "youtube"),
        StreamingApp(id: "primevideo", name: "Prime Video", imageName: "primevideo"),
        StreamingApp(id: "paramount", name: "Paramount+", imageName: "paramount"),
        StreamingApp(id: "hulu", name: "Hulu", imageName: "hulu"),
        StreamingApp(id: "peacock", name: "Peacock", imageName: "Peacock"),
        StreamingApp(id: "tubi", name: "Tubi", imageName: "tubi"),
        StreamingApp(id: "pluto", name: "Pluto TV", imageName: "pluto"),
        StreamingApp(id: "max", name: "Max TV", imageName: "max")
    ]

    /// The catalog apps for `ids`, in the order of `ids`. Unknown ids are skipped.
    static func apps(for ids: [String]) -> [StreamingApp] {
        ids.compactMap { id in catalog.first { $0.id == id } }
    }
}
