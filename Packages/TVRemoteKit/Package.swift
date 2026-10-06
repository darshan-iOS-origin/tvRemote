// swift-tools-version: 6.0
// All non-UI logic for the TV Remote app. The app target links only
// TVServices, TVCore, DesignSystem and AppSupport — never a brand module.
// See docs/ARCHITECTURE.md for the dependency rules.

import PackageDescription

let package = Package(
    name: "TVRemoteKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "TVCore", targets: ["TVCore"]),
        .library(name: "TVServices", targets: ["TVServices"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppSupport", targets: ["AppSupport"]),
    ],
    dependencies: [
        // Samsung Tizen control only (MIT). Used by TizenControl and nothing else.
        .package(url: "https://github.com/yuri-rod/smart-tv-remote-swift", .upToNextMinor(from: "1.1.1")),
    ],
    targets: [
        // Foundation layer
        .target(name: "TVCore"),
        .target(name: "TVNetworking", dependencies: ["TVCore"]),
        .target(name: "TVSecurity", dependencies: ["TVCore"]),
        .target(name: "TVStorage", dependencies: ["TVCore"]),
        .target(name: "TVDiscovery", dependencies: ["TVCore", "TVNetworking"]),
        .target(name: "TVCast", dependencies: ["TVCore", "TVNetworking"]),
        .target(name: "TVVoice", dependencies: ["TVCore"]),

        // One module per platform. Brands never import each other.
        .target(name: "RokuControl", dependencies: ["TVCore", "TVNetworking", "TVCast"]),
        .target(name: "AndroidTVControl", dependencies: ["TVCore", "TVNetworking", "TVSecurity", "TVStorage", "TVCast"]),
        .target(name: "TizenControl", dependencies: [
            "TVCore", "TVNetworking", "TVStorage", "TVCast",
            .product(name: "SmartCastKit", package: "smart-tv-remote-swift"),
        ]),
        .target(name: "WebOSControl", dependencies: ["TVCore", "TVNetworking", "TVStorage", "TVCast"]),
        .target(name: "VizioControl", dependencies: ["TVCore", "TVNetworking", "TVStorage", "TVCast"]),
        .target(name: "BraviaControl", dependencies: ["TVCore", "TVNetworking", "TVStorage", "TVCast"]),
        .target(name: "FireTVControl", dependencies: ["TVCore", "TVNetworking", "TVStorage"]),

        // Façade the app's view controllers talk to.
        .target(name: "TVServices", dependencies: [
            "TVCore", "TVDiscovery", "TVStorage", "TVVoice",
            "RokuControl", "AndroidTVControl", "TizenControl", "WebOSControl",
            "VizioControl", "BraviaControl", "FireTVControl",
        ]),

        // App-wide UI + support
        .target(name: "DesignSystem", dependencies: ["TVCore"]),
        .target(name: "AppSupport"),

        // Tests — no real TV needed; everything runs against TestSupport mocks.
        .target(name: "TestSupport", dependencies: ["TVCore", "TVNetworking"], path: "Tests/TestSupport"),
        .testTarget(name: "TVCoreTests", dependencies: ["TVCore", "TestSupport"]),
        .testTarget(name: "TVDiscoveryTests", dependencies: ["TVDiscovery", "TestSupport"]),
        .testTarget(name: "TVStorageTests", dependencies: ["TVStorage", "TestSupport"]),
        .testTarget(name: "RokuControlTests", dependencies: ["RokuControl", "TestSupport"]),
        .testTarget(name: "TVServicesTests", dependencies: ["TVServices", "TestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
