# TV Remote — Production Context

> Hand-off document for a **production-level rebuild in a separate repository**.
> It describes the existing demo app (`tvRemoteDemo`) accurately: what it does, how it is
> built, the TV-control protocols it speaks, the architecture worth reusing, and the gaps a
> production version must close.
>
> **Accuracy rules used here:** facts are taken from the actual code, `Info.plist`, and
> `tvRemoteDemo.xcodeproj/project.pbxproj`. Anything the code itself marks `UNVERIFIED` or
> `TODO(source)` — i.e. a protocol detail never confirmed on real hardware — is flagged the
> same way below. Do not promote those to "working" without device testing. The older
> `README.md` in this repo is a demo design doc and is partly out of date (see
> [Discrepancies](#discrepancies-trust-the-code)); **trust the code tree, not prose.**

---

## 1. Overview & product scope

A native iOS app that turns an iPhone into a Wi-Fi remote for smart TVs on the same local
network. An iPhone has no IR blaster, so the app does **not** control old TVs; it speaks each
brand's **network control protocol** (HTTP, HTTPS, WebSocket, or TLS sockets) over the LAN. No
cloud, no accounts, no analytics.

**Platforms with control implemented:** Roku, Android / Google TV, Samsung Tizen, LG webOS,
Vizio SmartCast, Sony Bravia (IP control), Amazon Fire TV.

**Deliberately out of scope:**
- **Apple TV** — excluded for privacy reasons (no AirPlay/companion-link discovery, no control).
- **Xbox controller mode** — dropped.
- **Infrared** — impossible on iPhone hardware.

**Brand vs. platform** are modeled as separate concepts: a TCL or Hisense set may run *Roku* or
*Android TV*; a Sony may run *Android TV* or its own *Bravia* IP control. See `TVBrand` and
`TVPlatform`.

**Feature set (user-facing):** automatic multi-method discovery; connect & pair; full remote
(power, volume, mute, channel, D-pad/OK/back/home/menu, playback, colour keys, HDMI inputs, Live
TV, number pad); touchpad and LG Magic-Remote pointer; on-screen keyboard text entry; app
launcher; voice (stream mic to the TV's assistant on Android TV, or on-device speech→command on
others); casting photos/video/audio (Google Cast / DLNA / Roku Media Player); AirPlay mirroring
*guide*; Wake-on-LAN; saved / favorite / default TVs.

---

## 2. Tech stack & requirements

| Area | Current state |
|---|---|
| Language | **Swift only** (no Obj-C). `SWIFT_VERSION = 5.0` language mode, built with Swift-6-era concurrency: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Uses `async/await`, `actor`, `Sendable`, `nonisolated` throughout. |
| UI | **UIKit + Storyboard entry point.** No SwiftUI. One storyboard scene (`Base.lproj/Main.storyboard`, root `ViewController`); almost all UI is built programmatically. `LaunchScreen.storyboard` for launch. |
| Min iOS | **~iOS 16 is the effective floor** (app target `IPHONEOS_DEPLOYMENT_TARGET = 16.0`). The project is internally contradictory (project-level `26.2`; old README says "iOS 15") — **resolve this deliberately in the rebuild.** Policy: gate newer APIs with `#available`, don't raise the whole-app target for one feature. |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`), no Mac Catalyst. Portrait + landscape. |
| Dependencies | **SPM only.** One remote package: `SmartCastKit` (`github.com/yuri-rod/smart-tv-remote-swift`, pinned `upToNextMinor` from **1.1.1**, MIT), used **only** by the Samsung controller. Everything else is Apple frameworks: `Foundation`, `UIKit`, `Network`, `Security`, `Speech`, `AVFoundation`. **No paid SDKs; do not add packages without asking.** |
| Xcode project | `.xcodeproj` only, `objectVersion = 77`, created/last-upgraded on **Xcode 26.2**. Uses **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`) — the folder tree on disk *is* the project; no manual file references to maintain. |
| Targets | Single app target `tvRemoteDemo` (`com.tvremote.universal.smartcontro`). No test target, no extensions. `DEVELOPMENT_TEAM = RSJHSQF3LP` (replace), `CODE_SIGN_STYLE = Automatic`, `MARKETING_VERSION = 1.0`. |
| Entitlements | **No `.entitlements` file exists.** The multicast networking entitlement is discussed but not added — SSDP multicast finds nothing until it is (see Discovery). |

**To run:** a Mac with Xcode (26.x to match the project), a real iPhone and a real TV on the same
Wi-Fi network. A free Apple ID runs it on-device; the paid Apple Developer Program ($99/yr) is
only needed to publish and to request the multicast entitlement.

---

## 3. Dependencies & licensing

**Shipped dependency:** `SmartCastKit` (MIT, © 2026 Yuri Barreira) — Samsung Tizen control only.

**Reference repos** the protocol knowledge came from. Code was *not* copied unless noted; only
request shapes, endpoints, and key names were used. **Check each licence before copying any
code** — only the two marked below were license-confirmed from their README.

| Repo | Used for | Licence |
|---|---|---|
| `yuri-rod/smart-tv-remote-swift` (SmartCastKit) | Discovery, Roku key names, Samsung control, DLNA, Wake-on-LAN | **MIT (confirmed)** |
| `swisspol/GCDWebServer` | Local HTTP server pattern for casting | **New BSD (confirmed)** |
| `odyshewroman/AndroidTVRemoteControl` | Android/Google TV pairing + key codes | check before use |
| `msonnino/LgTvWebOSSwift`, `WebOSClient` | LG pairing / controls | no formal licence / check |
| `wdesimini/TVCommanderKit` | Samsung control | check before use |
| `M1KE-27/xiaomi-remote` | Android TV protocol | check before use |
| `heathbar/vizio-smart-cast` + exiva's API notes | Vizio codes & requests | MIT / check |
| `pybravia`, `sony_bravia_psk`, `bravia-auth-and-remote` | Sony Bravia RPC/IRCC + auth | MIT / MIT / ISC |
| `hms-firetv` | Fire TV "Lightning" API | MIT |
| `HaishinKit.swift` | streaming (for future self-hosted mirroring) | check before use |

---

## 4. Architecture

**Pattern:** protocol-oriented MVC with a brand-neutral service layer. **View controllers talk
only to `ConnectionManager` and `PairingManager`** — they never import or call a brand controller
directly. Models are value types; stateful network sessions are `actor`s. One brand = one
controller = one file.

```
tvRemoteDemo/
├── App/
│   ├── AppDelegate.swift, SceneDelegate.swift
│   ├── Design/        AppTheme, AppColors, AppSpacing, AppShadows, AppCornerRadius  (design system)
│   └── Helper/         LoggerManager, AppLogStore, ThreadManager
├── Controllers/
│   └── ViewController.swift    (storyboard root; launch/discovery + DEBUG scaffolding — legacy location)
├── Core/
│   ├── Models/         TVDevice, TVBrand, TVPlatform, KeyCommand, TVApp
│   ├── Connection/     TVController (protocol), ConnectionManager (+Voice), PairingManager,
│   │                   TVPairing, TVError
│   ├── Controllers/    one file per brand + per-brand session/message/pairing/apps helpers
│   ├── Discovery/      the 4-method discovery stack + transports
│   ├── Storage/        DeviceStore (UserDefaults), TokenStore/MACStore (Keychain),
│   │                   FavoriteStore, AppSettings, TVForgetter
│   ├── Security/        ClientIdentity, RSAPublicKey, SelfSignedCertificate
│   ├── Cast/           LocalMediaServer, MediaPreparer
│   ├── Mirror/         AirPlayFinder, MirrorGuide
│   ├── Voice/          SpeechTranscriber, VoiceCommandParser
│   ├── Audio/          MicrophoneCapture
│   ├── Motion/         MotionPointer (LG pointer)
│   └── Wake/           WakeOnLAN
├── Features/           the screens (see §7)
├── Views/              BrandMenuBuilder
└── Base.lproj/         Main.storyboard, LaunchScreen.storyboard
```

### The core abstraction — `TVController`

`Core/Connection/TVController.swift` defines the brand-neutral interface every platform
implements:

```
connect() / disconnect()
send(_ key: KeyCommand)                 // translated to the TV's own protocol
send(_ text: TextCommand)               // insert / backspace / enter into focused field
apps() -> [TVApp]  /  launch(_ app:)    // installed list (Roku, LG) or fixed catalog (others)
openChannel(_ number: String)           // "5", "7.1"
startCasting() -> any CastSession       // TV fetches media URLs itself
startVoice() -> any VoiceSession        // 16-bit PCM 8 kHz mono → TV assistant; never stored
send(_ pointer: PointerCommand)         // Magic-Remote move/click/scroll
hardwareAddresses() -> [MACAddress]     // for Wake-on-LAN; empty when unknown
setTextInputMethod(_:)                  // debug: force keyPresses / keyTaps / inputMethod
```

The **capability model is the protocol extension**: default implementations throw the matching
`TVError.unsupported*` (`unsupportedText`, `unsupportedApps`, `unsupportedVoice`,
`unsupportedCasting`, `unsupportedChannels`, `unsupportedPointer`). A controller only implements
what its TV supports; everything else self-reports as unsupported instead of failing silently.
Everything is `Sendable` / `nonisolated`.

Associated types in the same file: `CastSession`, `VoiceSession`, `PointerCommand`
(`move/click/scroll`), `TextCommand` (`insert/backspace/enter`), `TextInputMethod`.

### Coordinators

- **`ConnectionManager`** (`actor`) — holds the active TV and its controller; reconnects when the
  app returns to foreground. `defaultController(for:)` is the platform→controller **factory**
  (switch on `TVPlatform`). Exposes static capability predicates (`canType`, `canCast`,
  `canOpenChannels`, `canUseVoice`, `canUsePointer`, `canLaunchApps`, `canControl`,
  `supports(_ key:on:)`) that **drive which UI shows** — these delegate to each controller's own
  key tables so the UI and the transport can never disagree. Also orchestrates Wake-on-LAN.
- **`PairingManager`** — picks a `TVPairing` by platform (`VizioPairing`, `AndroidTVPairing`,
  `SonyPairing`, `FireTVPairing`); `start` / `submit` / `cancel`; returns a `PairingOutcome`.
  Roku needs no pairing; Samsung and LG approve on-TV during `connect()`.

### Models (`Core/Models/`)

- **`KeyCommand`** — the brand-neutral key vocabulary (power, volume, mute, channel, nav/OK, back,
  home, menu, playback, media, colour keys, exit, subtitles, HDMI 1–4, Live TV, digits 0–9) with
  `displayName` and an SF Symbol `symbolName`. Each controller maps these to its own codes.
- **`TVPlatform`** — the control protocol (`roku`, `tizen`, `webOS`, `androidTV`, `smartCast`,
  `bravia`, `fireTV`, `unknown`). Carries the Bonjour service-type table, SSDP brand inference,
  `pairingKind`, and display names.
- **`TVBrand`** — a display name plus token-matching identification from SSDP fields, specificity
  merge rules (a maker name beats "Roku" beats "Other"), and the Apple exclusion.
- **`TVDevice`** — value type keyed by IPv4 host, with `merging(_:)` to combine sightings from
  different discovery methods and a `debugReport`.
- **`TVApp`** — a launchable app/channel entry.

---

## 5. TV control protocols (per brand)

The heart of the app. Transport helpers live in `Core/Discovery/` (`HTTPRequesting` /
`LocalHTTPClient`, `URLSessionDataFetcher`, `NWPortProber`, `NWBonjourBrowser`, SSDP transports).
**Self-signed TLS is trusted only for private IPv4 addresses** (`LocalTrustPolicy`, and
SmartCastKit's own trust delegate for Samsung) — never for internet hosts.

| Platform | Transport & port | Pairing | Files | Verified? |
|---|---|---|---|---|
| **Roku** | ECP over plain **HTTP :8060**. `POST /keypress/<Key>`, text `/keypress/Lit_<char>`, `GET /query/apps`, `POST /launch/<id>`, `GET /query/device-info`, Live TV `launch/tvinput.dtv` | none | `RokuController.swift`, `RokuCastSession.swift` | **Verified (demo-first brand)** |
| **Android / Google TV** | Android TV Remote v2 over **TLS :6466** (pairing **:6467**), length-framed protobuf-style frames; press+release per key | TLS **client certificate** + on-TV code (verified locally against the secret's hash before sending) | `AndroidTVController/Connection/RemoteSession/RemoteMessages/Pairing/PairingMessages/Apps.swift` | Works on a real Android TV; **ping-reply framing UNVERIFIED** |
| **Samsung Tizen** | WebSocket remote channel via SmartCastKit's `SamsungTizenClient`; ports **8001** (plain) / 8002 (secure); app launch REST `POST http://<ip>:8001/api/v2/applications/<id>` | on-TV **Allow** prompt → token in Keychain | `SamsungTizenController.swift`, `SamsungApps.swift` | Partly UNVERIFIED (Deny behaviour, token path) |
| **LG webOS** | **own** SSAP client over WebSocket, **:3001 (wss) / :3000 (ws)**; pointer input socket `ssap://com.webos.service.networkinput/getPointerInputSocket` sends `type:button`/`name:<BUTTON>`; power `ssap://system/turnOff` (cannot power on); play/pause `ssap://media.controls/play`; input `ssap://tv/switchInput` | on-TV **Accept** → `client-key` in Keychain | `LGWebOSController.swift`, `LGWebOSSession.swift` | UNVERIFIED: unsigned-manifest pointer grant per webOS version; play/pause toggle |
| **Vizio SmartCast** | local **HTTPS :7345 / :9000** (remembers which answered); keys `PUT /key_command/` with `{"KEYLIST":[{"CODESET":n,"CODE":n,"ACTION":"KEYPRESS"}]}` | `PUT /pairing/start` → `/pairing/pair` → `AUTH_TOKEN` (Keychain), sent as `AUTH` header | `VizioController.swift`, `VizioPairing.swift` | **UNVERIFIED entirely** on real hardware |
| **Sony Bravia (IP control)** | JSON-RPC to `http://<ip>/sony/<service>` + IRCC via SOAP `POST /sony/IRCC` (**:80**); TV lists its own IRCC name→code map, each key tries likely Sony names | `actRegister` **PIN** → `auth` cookie (Keychain) | `BraviaController.swift`, `BraviaMessages.swift`, `SonyPairing.swift` | **UNVERIFIED entirely** |
| **Amazon Fire TV** | local **HTTPS :8080** "Lightning" API; `X-Api-Key` + `X-Client-Token` headers; keys `POST /v1/FireTV?action=dpad_*|select|back|home|menu`, media `POST /v1/media?action=play`, apps `GET /v1/FireTV/appsV2`; **wake** plain HTTP `POST http://<ip>:8009/apps/FireTVRemote` | **PIN** (`/v1/FireTV/pin/display`, `/pin/verify`) | `FireTVController.swift`, `FireTVPairing.swift` | **UNVERIFIED entirely**; limited (no volume/power/channels/text) |

### Casting (`Core/Cast/` + `Core/Controllers/*CastSession*`)

- **Google Cast (CASTV2 over TLS :8009)** — `GoogleCastSession.swift`, `GoogleCastMessages.swift`
  (Android TV, Vizio).
- **DLNA / AVTransport** — `DLNACastSession.swift`, `DLNAMessages.swift` (Samsung/LG/Sony; Samsung
  fallback control URL `http://<ip>:9197/upnp/control/AVTransport1`).
- **Roku Media Player** — `RokuCastSession.swift`.
- The phone serves the media from a **token-guarded local HTTPS server** (`LocalMediaServer.swift`,
  `NWListener`, byte-range support), files prepared by `MediaPreparer.swift`. The TV fetches the
  URLs itself.

### Security (`Core/Security/`)

Android TV's TLS client identity: each install generates **its own RSA key and a hand-built DER
self-signed X.509 certificate** (`ClientIdentity`, `RSAPublicKey`, `SelfSignedCertificate`) — iOS
has no certificate-issuing API — stored in the Keychain. Nothing shared is shipped.

---

## 6. Discovery (`Core/Discovery/TVDiscoveryService.swift`)

Four methods run **concurrently**, streaming `TVDevice`s via `AsyncStream`, merged by host in a
private `DeviceMerger` actor. A device is only listed once its **brand is proven** — an open port
or a router/printer is never shown; Apple devices are filtered out.

1. **SSDP multicast** — needs Apple's multicast entitlement; **silently finds nothing without it**.
2. **SSDP unicast** (`UnicastSSDPTransport`) — M-SEARCH sent to every address in the phone's /24
   subnet, one by one. No entitlement needed. The general cross-brand finder; a UPnP device must
   answer a search to its own address, and its description names the maker + a TV/media service
   (DIAL or MediaRenderer).
3. **Bonjour** (`NWBonjourBrowser`) — the service types in `Info.plist`.
4. **Subnet port sweep** of **verified** control ports, each with a brand proof (`BrandProbes.swift`):
   Roku 8060 (device-info reply), Samsung 8001 (JSON description), LG 3001/3000 (SSAP error reply).
   Android TV (6466/6467) and Vizio (7345/9000) ports are present but marked **unverified** and are
   not swept as proof.

Supporting files: `ControlPorts.swift`, `SSDPResponseParser.swift`, `DeviceDescriptionParser.swift`,
`UPnPLocator.swift`, `IPv4.swift`, `InterfaceSubnetProvider.swift`, `ManualTVProbe.swift` (emulator
by IP), `LocalNetworkAuthorizer.swift`, `DiscoveryTransports.swift`, `UDPSSDPTransport.swift`.

---

## 7. Features / screens (`Features/`)

| Screen | File(s) |
|---|---|
| Launch / discovery (storyboard root) | `Controllers/ViewController.swift` (Local Network permission, scan, list found + saved, DEBUG "Test on Emulator") |
| Device list / detail | `Discovery/DeviceListViewController.swift`, `DeviceDetailViewController.swift`, `DeviceSorting.swift` |
| Pairing (code entry) | `Pairing/PairingViewController.swift`, `PairingPresentation.swift` |
| Remote | `Remote/RemoteViewController.swift` + `RemoteLayout`, `RemoteSection`, `RemoteKeyTileCell`, `RemoteSectionHeaderView`, `RemotePresentation`, `TouchpadView`, `DirectionalPadView` (Google-TV pad), `PointerView` + `PointerSender` (LG Magic Remote), `VoiceAssistant` |
| Keyboard | `Keyboard/KeyboardViewController.swift` (types into focused TV field; **text never logged**) |
| Apps launcher | `Apps/AppsLauncherViewController.swift` |
| Number pad | `Numbers/NumberPadViewController.swift` |
| Favorites | `Favorites/FavoritesViewController.swift` |
| Cast | `Cast/CastViewController.swift` |
| Mirror | `Mirror/MirrorViewController.swift` (**only guides** the user to AirPlay; the app cannot start mirroring itself) |
| Manage TVs | `Devices/ManageTVsViewController.swift` (rename / forget / set default) |
| Settings + Licences | `Settings/SettingsViewController.swift`, `LicencesViewController.swift` |
| Logs | `Logs/LogsVC.swift`, `LogViewerAccess.swift` (in-app floating log button, installed on the window in `SceneDelegate`) |

Remote key tiles use `UICollectionViewDiffableDataSource`, with three input modes
(buttons / touchpad / pointer), a per-TV layout, and **unsupported keys hidden** via the
`ConnectionManager` capability predicates.

Voice: on Android TV the mic audio streams to the TV's assistant; on other platforms the phone
does **on-device** speech-to-text (`SpeechTranscriber`) and `VoiceCommandParser` turns it into
`KeyCommand`s. Audio is never recorded or stored.

---

## 8. `Info.plist` & permissions

- `NSAppTransportSecurity → NSAllowsLocalNetworking = true` — Roku/Samsung/Sony use plain HTTP on
  the LAN. **ATS is not globally disabled.**
- `NSLocalNetworkUsageDescription` — find and control TVs on Wi-Fi.
- `NSBonjourServices` — `_androidtvremote2._tcp`, `_samsungmsf._tcp`, `_bonjour._tcp`, `_lnp._tcp`,
  `_airplay._tcp`, `_amzn-wplay._tcp`.
- `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` — voice; speech is
  on-device, audio never stored.
- `UIApplicationSceneManifest` — single scene, `SceneDelegate`, storyboard `Main`,
  `UIApplicationSupportsMultipleScenes = false`.
- **Absent:** `com.apple.developer.networking.multicast` entitlement / any `.entitlements` file.

---

## 9. Build & run

1. Open `tvRemoteDemo.xcodeproj` in Xcode (26.x to match the project). SPM resolves `SmartCastKit`
   automatically; if not, File → Add Package Dependencies → `https://github.com/yuri-rod/smart-tv-remote-swift`.
2. Set your own `DEVELOPMENT_TEAM` (currently `RSJHSQF3LP`). A free Apple ID runs it on-device.
3. **No shared scheme is checked in** — Xcode auto-generates the single `tvRemoteDemo` scheme. The
   rebuild should commit a shared scheme.
4. Run on a **real iPhone** (the simulator can't see TVs). A DEBUG-only path connects to an Android
   TV emulator by IP with ports 6466/6467 forwarded.
5. Allow the Local Network prompt. For Roku, enable control by mobile apps
   (Settings → System → Advanced system settings; network access Default or Permissive).

---

## 10. Conventions (from `.cursor/rules/tv-remote-app.mdc`)

Carry these into the rebuild — they encode hard-won lessons:

- **Concurrency:** `async/await`; `@MainActor` for UI; `actor`s for stateful sessions. Typed
  `TVError`. **No force-unwraps, no `try!`.**
- **Networking:** never block the main thread; a **timeout on every request**; support
  cancellation. Trust self-signed certs **only for local IPs**. **Do not invent endpoints, ports,
  or payloads** — if unsure, leave a `TODO(source)` with the reference to check. Keep subnet probing
  as the multicast fallback.
- **Architecture:** brand-neutral `TVController` + `KeyCommand`; one brand per file; VCs touch only
  `ConnectionManager` / `PairingManager`; **capability-driven UI** (hide/disable what a TV lacks).
  Keep VCs small; logic lives in services and models; prefer value types.
- **Storyboard:** one scene per VC, storyboard ID = class name; don't hand-edit storyboard XML;
  Auto Layout, Dark Mode, all iPhone sizes.
- **Change discipline:** smallest change that meets the request; mark `UNVERIFIED` assumptions
  clearly; after each change, state what to test on a real TV, noting model + firmware.

---

## 11. Privacy & security

- **Local network only.** No cloud calls, no ad/analytics SDKs in the demo.
- **Never log or store** text typed through the keyboard (it can contain passwords) — enforced
  in code comments and `TextCommand` handling.
- Pairing tokens and keys live in the **Keychain**, never `UserDefaults`. `DeviceStore` saves only
  benign device metadata (name, brand, platform, address, model).
- Ask for Local Network and Speech permissions only when first needed.
- Show a clear **consent screen before screen mirroring**.
- Use brand names factually, **no logos**, add a "not affiliated" disclaimer.

---

## 12. Known limits & risks

- Most non-Roku control protocols are **unofficial**; a TV firmware update can break a feature.
- Per-TV variance: power-on, casting, and mirroring are not available on every TV — check at
  runtime and reflect it in the UI.
- The **multicast entitlement** needs Apple's approval (days–weeks); until then SSDP multicast
  finds nothing and the unicast/Bonjour/port-sweep fallbacks carry discovery.
- App Store review can reject this category for paywalls that block basic buttons (e.g. volume) —
  keep basic controls free.
- **Vizio, Sony, and Fire TV controllers are UNVERIFIED on real hardware in their entirety**, and
  several Samsung / LG / Android specifics are unverified — budget device testing per brand/model.

---

## 13. Production gaps to close in the rebuild

Things the demo deliberately skips or left rough; a production app should address them. These are
recommendations, not descriptions of current code.

- **Tests.** The demo has **no test target** (Cursor rules forbade unit tests). Production should
  add unit tests (protocol translation, discovery parsing, pairing state machines, token storage)
  and a UI/smoke suite, plus mock `TVController` / `HTTPRequesting` implementations for CI without
  real TVs.
- **CI/CD.** No CI exists; add build + test + lint (SwiftLint/SwiftFormat) and signing automation.
- **Shared scheme & signing.** Commit a shared scheme; parameterize the development team.
- **Module split.** Single app target. The `Core/` vs `Features/` seam, and one-file-per-brand,
  are a natural fit for SPM modules (e.g. `TVControlKit`, `TVDiscoveryKit`, per-brand modules) —
  which also makes per-brand testing cleaner.
- **Analytics.** Planned but not built; introduce behind one `Analytics` protocol so the
  "no SDK in demo" stance stays swappable, with explicit consent.
- **Device verification matrix.** Replace the `UNVERIFIED` flags with a tracked matrix of
  brand × model × firmware test results before claiming support.
- **Deployment-target decision.** Resolve the 16.0 vs 26.2 vs "iOS 15" contradiction to one real
  floor, keeping `#available` gates for newer-only features (e.g. ScreenCaptureKit mirroring).
- **Stale brand gate.** `TVBrand.isSupported` still returns `true` only for Roku (a demo-first
  TODO) even though controllers now exist for every listed platform; the real capability source of
  truth is `ConnectionManager`'s predicates. Reconcile these so the UI gate matches reality.
- **Legacy placement.** `Controllers/ViewController.swift` carries DEBUG scaffolding and sits
  outside `Features/Discovery/`; fold it in and strip debug-only paths from release builds.
- Also consider: full localization, an accessibility audit (VoiceOver on the remote grid), and
  crash/error telemetry.

---

## Discrepancies (trust the code)

The repo's existing 56 KB `README.md` is a demo working doc and disagrees with the code in places:
its architecture diagram uses idealized names (`TVRemote/…`, `DeviceDiscoveryVC`, `TVCapability`)
that don't match the current tree; it states "iOS 15 / Xcode 15" where the project is iOS 16 /
Xcode 26.2; and it predates several brands and folders (`Core/Audio`, `Core/Mirror`, `Core/Motion`,
`Core/Security`, `Core/Voice`, `Core/Wake`, `App/Design`, `App/Helper`, `Views/`). Where this
document and the old README disagree, **this document and the code win.**
