# Architecture & folder structure

The app is split in two:

- **`remote/`** — the Xcode app target. UI only: view controllers, views, storyboards, assets.
  It uses file-system-synchronized groups, so **the folder tree on disk is the project**: add a
  folder or file here and Xcode picks it up; no manual file references.
- **`Packages/TVRemoteKit/`** — a local Swift package holding all non-UI logic (models,
  discovery, networking, per-brand control, storage). Each folder under `Sources/` is a module,
  so the boundaries below are enforced by the compiler, not by convention.

## Folder tree

```
tvRemote/
├── README.md                     production context (protocols, scope, gaps)
├── docs/
│   ├── ARCHITECTURE.md           this file
│   ├── DEVICE_MATRIX.md          brand × model × firmware test results (to add)
│   └── adr/                      architecture decision records (to add)
├── Config/                       xcconfigs; Signing.local.xcconfig git-ignored (to add)
├── .github/workflows/            CI: build + test + lint (to add)
│
├── remote/
│   ├── remote.xcodeproj/         commit a shared scheme under xcshareddata/xcschemes/
│   ├── remote/
│   │   ├── App/                  AppDelegate, SceneDelegate, AppEnvironment (builds services)
│   │   ├── Features/             one folder per screen: VC + its views + presentation models
│   │   │   ├── Onboarding/       Local Network permission, "not affiliated" disclaimer
│   │   │   ├── Discovery/        scan, device list/detail (storyboard root lives here)
│   │   │   ├── Pairing/
│   │   │   ├── Remote/           RemoteViewController, layout, sections, key-tile cells
│   │   │   │   ├── Touchpad/     TouchpadView, DirectionalPadView
│   │   │   │   ├── Pointer/      PointerView, PointerSender, MotionPointer (LG)
│   │   │   │   └── Voice/        VoiceAssistant UI
│   │   │   ├── Keyboard/  Apps/  NumberPad/  Favorites/
│   │   │   ├── Cast/  Mirror/    Mirror only guides to AirPlay, behind a consent screen
│   │   │   ├── ManageTVs/  Settings/   (Settings includes Licences)
│   │   │   └── Debug/            log viewer, emulator-by-IP; wrap in #if DEBUG
│   │   ├── Resources/            Assets.xcassets, Base.lproj storyboards, Localizable.xcstrings
│   │   └── Supporting/           Info.plist, remote.entitlements (multicast, once granted)
│   ├── remoteTests/              app-level tests (to add)
│   └── remoteUITests/            smoke tests against MockTVController (to add)
│
└── Packages/TVRemoteKit/
    ├── Package.swift
    ├── Sources/
    │   ├── TVCore/               models, TVController protocol, KeyCommand, TVError
    │   ├── TVNetworking/         HTTP client, local-only TLS trust, WebSocket/TLS framing, port prober
    │   ├── TVSecurity/           Android TV client certificate (RSA key + self-signed X.509)
    │   ├── TVStorage/            DeviceStore (UserDefaults), Keychain token/MAC stores, favorites, settings
    │   ├── TVDiscovery/          SSDP multicast + unicast, Bonjour, port sweep + brand probes, parsers
    │   ├── TVCast/               local media server, media preparer, Google Cast, DLNA
    │   ├── TVVoice/              on-device speech, voice→KeyCommand parser, mic capture
    │   ├── RokuControl/          ┐
    │   ├── AndroidTVControl/     │
    │   ├── TizenControl/         │ one module per platform: controller + session,
    │   ├── WebOSControl/         │ messages, pairing, app catalog for that brand
    │   ├── VizioControl/         │
    │   ├── BraviaControl/        │
    │   ├── FireTVControl/        ┘
    │   ├── TVServices/           ConnectionManager, PairingManager, Wake-on-LAN (the app-facing façade)
    │   ├── DesignSystem/         theme, colors, spacing, shared components, BrandMenuBuilder
    │   └── AppSupport/           logging, in-app log store, Analytics protocol
    └── Tests/
        ├── TestSupport/          MockTVController, MockHTTPRequesting, fixtures
        └── <Module>Tests/        one test target per module
```

## Dependency rules

```
App Features ──► TVServices ──► *Control (brands) ──► TVNetworking ──► TVCore
     │               │                 │                TVSecurity
     │               ├──► TVDiscovery  ├──► TVCast
     │               ├──► TVStorage    └──► TVStorage
     │               └──► TVVoice
     ├──► TVCore (models only)
     ├──► DesignSystem
     └──► AppSupport
```

1. `TVCore` depends on nothing.
2. Brand modules (`*Control`) depend only on foundation modules. **Brands never import each other.**
3. `SmartCastKit` is linked only by `TizenControl`.
4. `TVServices` is the only module that knows every brand; it owns the platform → controller factory
   and the capability predicates that decide which UI is shown.
5. The app target links `TVServices`, `TVCore`, `DesignSystem` and `AppSupport` — **never a brand
   module.** View controllers talk only to `ConnectionManager` and `PairingManager`.

## Where does a new file go?

| You're adding… | Put it in |
|---|---|
| A screen or a view used by one screen | `remote/remote/Features/<Screen>/` |
| A reusable UI component or design token | `DesignSystem` |
| A new key, model field, or error case | `TVCore` |
| Support for a new TV platform | a new `<Platform>Control` module + a case in `TVServices`' factory |
| A protocol detail for an existing brand | that brand's `*Control` module |
| Anything stored on device | `TVStorage` (secrets → Keychain only) |
| A mock or fixture | `Tests/TestSupport` |

## Setup on a Mac

The package is not yet referenced by the Xcode project. Once:

1. Open `remote/remote.xcodeproj` (Xcode 26.x).
2. File → Add Package Dependencies → Add Local… → select `Packages/TVRemoteKit`.
3. Add the `TVServices`, `TVCore`, `DesignSystem` and `AppSupport` products to the `remote` target.
4. To run the package tests on their own, open `Packages/TVRemoteKit/Package.swift` in Xcode and
   press ⌘U with an iOS Simulator selected.
