# Analytics Events — Integration Context

Context for porting this app's event tracking to another iOS project. Covers the SDKs, the rules every
event follows, where each event goes, and the full event catalog as implemented in `tvRemote`.

Source of truth in this repo: `remote/remote/Manager/Firebase/FirebaseEvents.swift` (names) and
`remote/remote/Manager/Firebase/AnalyticsManager.swift` (sending).

---

## 1. SDKs and setup

| SDK | Purpose | Setup file |
|---|---|---|
| Firebase Analytics | All events (primary sink) | `Manager/Firebase/FirebaseManager.swift`, `AnalyticsManager.swift` |
| Firebase Crashlytics | Crash reports | `Manager/Firebase/CrashlyticsManager.swift` |
| Firebase Remote Config | IAP screen switches, free-use limits | `Manager/Firebase/RemoteConfigManager.swift` |
| Facebook App Events | Screen events + IAP entry per screen | `Manager/Facebook/FacebookManager.swift`, `FacebookEvents.swift` |
| Microsoft Clarity | Session recording + screen and IAP events | `Manager/Clarity/ClarityManager.swift`, `ClarityEvents.swift` |
| RevenueCat | Subscriptions; feeds trial/renewal events | `Manager/Subscription/SubscriptionManager.swift` |
| OneSignal | Push (no analytics events) | `Manager/OneSignal/OneSignalManager.swift` |

**Launch order** (`AppDelegate.didFinishLaunching`):

```swift
FirebaseManager.configure()                 // first
CrashlyticsManager.shared.configure()       // needs Firebase
AnalyticsManager.shared.logAppColdStart()   // app_cold_start
RemoteConfigManager.shared.setUp()
Task { await RemoteConfigManager.shared.fetchAndActivate() }
SubscriptionManager.shared.configure()      // RevenueCat (+ AdServices attribution token)
OneSignalManager.shared.configure(launchOptions:)
FacebookManager.shared.configure(application:launchOptions:)
ClarityManager.shared.configure()           // must run on main thread
```

**Keys** live in a git-ignored `Utils/Secrets.swift` (`revenueCatAPIKey`, `oneSignalAppID`, `facebookAppID`,
`facebookClientToken`, `clarityProjectID`) plus `GoogleService-Info.plist`. Never commit real values.

**Other setup:**
- `Info.plist`: SKAdNetwork identifiers (Google AdMob list, ~50 entries). `NSUserTrackingUsageDescription` is set
  as the build setting `INFOPLIST_KEY_NSUserTrackingUsageDescription`. Facebook App ID / client token are set in code
  (`FacebookManager`), not in `Info.plist`.
- Scheme launch argument `-FIRDebugEnabled` for Firebase DebugView.
- Debug builds: Firebase logger `.debug`, Facebook logging behaviours `.appEvents/.networkRequests/.informational`
  and an immediate `AppEvents.shared.flush()` after each event, Clarity log level `.verbose`.
- Facebook `isAdvertiserTrackingEnabled` is synced from the ATT status at launch, after the ATT prompt,
  and on every `didBecomeActive`. Only `.authorized` turns it on.

---

## 2. Rules every event follows

1. **Names:** max **35 chars** (Firebase allows 40; 35 leaves room for the `pro_` prefix), letters/digits/underscore,
   starts with a letter, must not start with `firebase_`, `google_`, `ga_`. Invalid names are dropped and logged.
2. **No parameters.** Everything is encoded in the event name (entry point, plan, screen, reason).
3. **All names are constants** in one `FirebaseEvents` enum. Call sites never build strings, except the
   documented builders (`IAPTracker`, `TrialTracker`, `RenewalTracker`, `myAppsApp(id)` etc.).
4. **`pro_` prefix:** tap and feature success/fail events get `pro_` prepended when the user is Premium
   (`marksPremium: true`, the default). Screens, permissions, IAP, trial and renewal events pass
   `marksPremium: false` and are identical for everyone.
5. **Once-per-install events** (`logOnce`) use a `UserDefaults` flag `analytics.once.<name>`; used for permission events.
6. **Console log:** every send prints `📊 EVENT_TRACK | 🔥 Firebase | <name>` (📘 Facebook, 🔭 Clarity);
   drops print `DROPPED <name>: <reason>`. Filter Xcode console with `EVENT_TRACK`.

### Core API

```swift
AnalyticsManager.shared.log(_ name: String,
                            parameters: [String: Any]? = nil,
                            marksPremium: Bool = true,   // adds pro_ for Premium users
                            clarity: Bool = false)       // also send to Clarity
AnalyticsManager.shared.logOnce(_ name: String)          // once per install, no pro_
AnalyticsManager.shared.logScreen(_ name: String)        // Firebase + Facebook + Clarity
AnalyticsManager.shared.logAppColdStart()
```

---

## 3. Routing: which SDK gets what

| Event group | Firebase | Facebook | Clarity | `pro_` prefix |
|---|---|---|---|---|
| `app_cold_start` | ✅ | — | — | no |
| Screens (`screen_*`) | ✅ | ✅ same name | ✅ same name + `setCurrentScreenName` | no |
| Permissions | ✅ once/install | — | — | no |
| IAP entry `iap_open_<entry>` | ✅ | — | ✅ | no |
| IAP entry per screen `iap_open_<entry>_<main\|offer\|trial>` | — | ✅ only | — | no |
| IAP flow (`<entry>_...`) | ✅ | — | ✅ | no |
| Trial / renewal | ✅ | — | ✅ | no |
| Taps (`*_tap`) | ✅ | — | only `clarityTaps` set | yes |
| Feature results (`*_ok`, `*_fail_*`) | ✅ | — | — | yes |

`clarityTaps` = `premium_start_tap`, `iap_buy_fail_alert_ok_tap`, `iap_restore_none_ok_tap`, `iap_restore_fail_ok_tap`.

---

## 4. Event catalog

### 4.1 App lifecycle
- `app_cold_start` — process launched from terminated state.

### 4.2 Screens (`logScreen` in each VC's `viewDidAppear`)
`screen_splash`, `screen_onboarding_1`, `screen_onboarding_2`, `screen_onboarding_3` (one per pager page),
`screen_scanning`, `screen_remote`, `screen_cast`, `screen_mirroring`, `screen_keyboard`, `screen_my_apps`,
`screen_add_apps`, `screen_favourites`, `screen_history`, `screen_my_tvs`, `screen_settings`,
`screen_app_theme`, `screen_app_icon`, `screen_feedback`, `screen_voice`, `screen_subscription`,
`screen_free_trial`, `screen_offer_subscription`, `screen_premium_activated`, `screen_app_icon_sheet`,
`screen_pairing_code_alert`, `screen_connection_required`, `screen_no_internet_alert`,
`screen_magic_cursor_alert`, `screen_text_input_alert`.

Custom dialogs (pairing code, connection required, no internet, etc.) count as screens.

### 4.3 Permissions (once per install, only when the system alert was really shown)
Pattern: `<perm>_permission_trigger | _allowed | _deny`

| Permission | Prefix |
|---|---|
| App Tracking Transparency | `att_permission_*` |
| Notifications | `notification_permission_*` |
| Microphone | `mic_permission_*` |
| Speech recognition | `speech_permission_*` |
| Local network | `local_network_permission_*` |

`restricted` counts as `deny`. Silent status checks (no alert shown) log nothing.

App's own "open Settings" alerts after a denial (logged every time):
`local_network_settings_alert|_open|_cancel`, `voice_settings_alert|_open|_cancel`, `cast_settings_alert|_open|_cancel`.

### 4.4 IAP entry points — `iap_open_<entry>`
Logged when the IAP screen really opens (not on tap). Premium users skip the IAP flow, so no event.

| Event | Opened from |
|---|---|
| `iap_open_splash` | Launch flow (returning user) |
| `iap_open_scanning` | First-launch flow after scan |
| `iap_open_setting_banner` | Settings Pro banner |
| `iap_open_remote_limit` | Free remote-tap limit reached |
| `iap_open_keyboard_limit` | Free keyboard-tap limit reached |
| `iap_open_mirror_limit` | Free mirror-start limit reached |
| `iap_open_mirror_quality` | Locked mirror quality chip |
| `iap_open_cast_limit` | Free cast limit reached |
| `iap_open_add_tv_limit` | Free saved-TV limit reached |
| `iap_open_history_locked_tv` | Locked TV in History |
| `iap_open_my_tvs_favorite` | Favourite in My TVs |
| `iap_open_app_theme_locked` | Locked app theme |
| `iap_open_app_icon_sheet` | App icon premium sheet |

`<entry>` below = the part after `iap_open_` (e.g. `setting_banner`). It stays the same for the whole IAP
session, including the Main → Offer → Free Trial chain.

### 4.5 IAP flow — built by `IAPTracker` (Firebase + Clarity)

| Pattern | Steps |
|---|---|
| `<entry>_<step>` | `year_plan_default`, `month_plan_change`, `year_plan_change`, `main_close`, `offer_close`, `trial_close`, `privacy_tap`, `terms_tap` |
| `<entry>_<screen>_<step>` purchase | `buy_start`, `buy_ok`, `buy_cancel`, `buy_fail` |
| `<entry>_<screen>_<step>` restore | `restore`, `restored`, `restore_no` |

`<screen>` = `main` (SubscriptionVC), `offer` (OfferSubscriptionVC), `trial` (FreeTrailVC).
Examples: `setting_banner_month_plan_change`, `scanning_offer_buy_start`, `splash_main_restored`.

Facebook only: `iap_open_<entry>_<screen>` when each IAP screen appears (`IAPTracker.screenAppeared`).

### 4.6 Free trial — built by `TrialTracker` (Firebase + Clarity)
Pattern: `<entry>_<m|y>trial_<step>` — `m` monthly, `y` yearly. Without a known entry (bought on another
device / older version): `<m|y>trial_<step>`.

Steps (each once per trial): `started`, `converted`, `cancelled`, `resumed`, `expired`, `bill_fail`.
Example: `setting_banner_mtrial_started`.

Detected from RevenueCat `CustomerInfo` (entitlement `periodType == .trial`, `willRenew`,
`billingIssueDetectedAt`) whenever customer info arrives, i.e. on app open — not in real time.

### 4.7 Paid renewal — built by `RenewalTracker` (Firebase + Clarity)
Pattern: `<entry>_<m|y>sub_<step>`, no-entry form `<m|y>sub_<step>`.

Steps: `renewed`, `first_renew` (once), `cancelled`, `resumed`, `expired`, `bill_fail`, `resubscribed`.
Plan switch: `<entry>_sub_to_year` / `<entry>_sub_to_month`.
The entry point carries over from a converted trial. Multiple renewals between opens log one `renewed`.

### 4.8 Taps — `<screen>_<element>_tap` (`pro_` for Premium)

**Onboarding:** `onboarding_1_continue_tap`, `onboarding_2_continue_tap`, `onboarding_3_continue_tap`;
brands `onboarding_brand_{roku,samsung,lg,sony,vizio,android_tv,fire_tv,other}_tap`.

**Scanning:** `scanning_close_tap`, `scanning_rescan_tap`, `scanning_tv_tap`, `scanning_notv_rescan_tap`, `scanning_notv_okay_tap`.

**Pairing dialog:** `pairing_pair_tap`, `pairing_cancel_tap`.

**Tab bar:** `tab_remote_tap`, `tab_apps_tap`, `tab_keyboard_tap`, `tab_favourites_tap`, `tab_settings_tap`.

**Remote tab:** `remote_keyboard_tap`, `remote_history_tap`, `remote_add_tv_tap`,
`remote_seg_buttons_tap`, `remote_seg_touchpad_tap`, `remote_seg_lg_tap`, `remote_cast_tap`, `remote_voice_tap`,
`remote_mirror_tap`, `remote_pad_ok_tap`, `remote_cursor_tap`, `remote_cursor_gotit_tap`, `remote_cursor_click_tap`,
`remote_play_tap`, `remote_play_pause_tap`.
Keys: `remote_{power,up,down,left,right,ok,vol_up,vol_down,ch_up,ch_down,prev,next,stop,live_tv,input,back,home,menu,info,hdmi_1..4,rewind,forward,red,green,yellow,blue,subtitle}_tap`.

**Keyboard tab:** `keyboard_text_tap`, `keyboard_history_tap`, `keyboard_add_tv_tap`, `keyboard_backspace_tap`, `keyboard_digit_0..9_tap`.

**My Apps / Add Apps:** `myapps_add_tap`, `myapps_add_more_tap`, `myapps_app_<id>_tap`, `addapps_back_tap`, `addapps_add_tap`, `addapps_app_<id>_tap`.

**Favourites:** `favourites_tv_tap`, `favourites_heart_tap`, `favourites_connect_tap`, `favourites_cancel_tap`.

**Settings:** `setting_change_icon_tap`, `setting_app_theme_tap`, `setting_share_tap`, `setting_rate_tap`, `setting_feedback_tap`, `setting_privacy_tap`.

**Cast:** `cast_back_tap`, `cast_photo_tap`, `cast_video_tap`, `cast_files_tap`, `cast_prev_tap`, `cast_play_pause_tap`, `cast_next_tap`, `cast_stop_tap`.

**Screen Mirroring:** `mirror_back_tap`, `mirror_seg_smart_tv_tap`, `mirror_seg_web_tap`, `mirror_primary_tap`,
`mirror_480p_tap`, `mirror_720p_tap`, `mirror_1080p_tap`, `mirror_copy_tap`, `mirror_share_tap`.

**History:** `history_back_tap`, `history_tv_tap`, `history_default_tap`, `history_rename_tap`, `history_delete_tap`,
`history_delete_ok_tap`, `history_delete_cancel_tap`, `history_rename_ok_tap`, `history_rename_cancel_tap`.

**My TVs:** `mytvs_back_tap`, `mytvs_add_tap`, `mytvs_heart_tap`, `mytvs_connect_tap`, `mytvs_disconnect_tap`, `mytvs_scan_ok_tap`, `mytvs_scan_cancel_tap`.

**Voice:** `voice_back_tap`, `voice_mic_tap`.

**App Theme:** `apptheme_back_tap`, `apptheme_apply_tap`, `apptheme_1..6_tap`.

**App Icon:** `appicon_back_tap`, `appicon_apply_tap`, `appicon_sheet_premium_tap`, `appicon_sheet_close_tap`, `appicon_1..6_tap`.

**Feedback:** `feedback_back_tap`, `feedback_send_tap`; reasons `feedback_{not_good,crashes,poor,slow,difficult,excellent,disappointing,other}_tap`.

**Shared dialogs:** `typetv_send_tap`, `typetv_cancel_tap`, `connect_alert_connect_tap`, `connect_alert_later_tap`,
`no_internet_retry_tap`, `no_internet_close_tap`, `premium_start_tap`.

**OK button of every plain alert** (one event per alert, required by `showSimpleAlert(okEvent:)`):
`appicon_alert_ok_tap`, `apptheme_alert_ok_tap`, `feedback_pick_alert_ok_tap`, `feedback_other_alert_ok_tap`,
`myapps_na_alert_ok_tap`, `myapps_error_alert_ok_tap`, `keyboard_alert_ok_tap`, `remote_alert_ok_tap`,
`voice_noconn_alert_ok_tap`, `voice_unsupported_alert_ok_tap`, `voice_error_alert_ok_tap`, `cast_alert_ok_tap`,
`scan_port_alert_ok_tap`, `scan_address_alert_ok_tap`, `scan_notv_alert_ok_tap`, `connect_fail_alert_ok_tap`,
`mail_setup_alert_ok_tap`, `iap_buy_fail_alert_ok_tap`, `iap_restore_none_ok_tap`, `iap_restore_fail_ok_tap`.

**System sheets closed / finished:** `mirror_share_cancel_tap`, `setting_share_cancel_tap`, `cast_photo_cancel_tap`,
`cast_files_cancel_tap`, `feedback_mail_sent_tap`, `feedback_mail_cancel_tap`.

### 4.9 Feature results — success / fail per reason (`pro_` for Premium)
Fail events name the reason; helper functions map the error → name so call sites never build names.

| Feature | Success | Fail events |
|---|---|---|
| Scan | `scan_found_tv` | `scan_found_none` |
| Connect | `connect_ok` | `connect_fail_{unreachable,timeout,refused,denied,noapprove,notpaired,other}` |
| Pairing code | `pair_code_ok` | `pair_code_wrong`, `pair_fail_{unsupported,unreachable,timeout,pending,rejected,badresp,identity}` |
| Add TV by IP | `connect_manual_ok` | `connect_manual_{nolocal,noport,noanswer}` |
| Remote key | — | `remote_fail_{timeout,refused,denied,notpaired,nokey,unreachable}` |
| Keyboard digit | — | `keyboard_fail_{timeout,refused,denied,notpaired,unreachable}` |
| Type on TV | `typetv_ok` | `typetv_fail_{unreachable,timeout,unsupported,other}` |
| Voice | `voice_ok` | `voice_fail_{mic_denied,speech_denied,nomodel,mic_error,nothing_heard,other}` |
| Launch app | `myapps_launch_ok` | `myapps_fail_{not_on_tv,unreachable,timeout,refused,other}` |
| Cast | `cast_play_ok` | `cast_fail_{localnet,toolarge,nowifi,server,prepare,tv_timeout,tv_unsupported,tv_format,tv_unreachable}` |
| Mirror | `mirror_tv_ok`, `mirror_web_ok` | `mirror_fail_{localnet,nowifi,server,tv_timeout,tv_unsupported,tv_format,tv_unreachable}` |
| App icon | `appicon_change_ok` | `appicon_fail_{unsupported,error}` |
| App theme | `apptheme_apply_ok` | — |
| Remote Config | `rc_fetch_ok` | `rc_fetch_fail` |

---

## 5. Related behaviour worth porting

- **Remote Config keys:** `iap_main_screen`, `iap_year_offer_screen`, `iap_free_trial_screen` (bool, IAP chain),
  `remote_click_limit`, `screen_mirror_click_limit`, `add_new_tv_limit`, `screen_cast_limit` (numbers, free limits),
  `year_free_trial`, `month_free_trial` (bool). Every key has an in-code default. Fetch interval 0 in DEBUG, 3600 in release.
- **IAP chain** (`IAPFlowManager`): Main → Offer → Free Trial, each enabled by Remote Config; Free Trial is the
  fallback when both others are off. Next screen opens on X; the last X dismisses the stack. Premium ends the chain.
- **Rate prompt** (`RateUsManager`): system review alert at most once per install, after a feature success
  (connect, voice, cast end, mirror end, app icon, app theme), never during an IAP session.
- **RevenueCat:** `Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()` right after configure.

---

## 6. Porting checklist

1. Add SDKs (SPM): Firebase (Analytics, Crashlytics, RemoteConfig), FacebookCore, Clarity, RevenueCat, OneSignal.
2. Copy `FirebaseManager`, `AnalyticsManager`, `EventLog`, `FacebookManager`/`FacebookEvents`,
   `ClarityManager`/`ClarityEvents`, `PermissionLogger`, `IAPTracker`, `TrialTracker`, `RenewalTracker`.
3. Create a fresh `FirebaseEvents` enum for the new app's screens/buttons, following the naming rules in §2.
4. Add `Secrets.swift` (git-ignored) and `GoogleService-Info.plist`; SKAdNetwork IDs in `Info.plist`; ATT usage string.
5. Wire the launch order in §1; call `FacebookManager.shared.syncTrackingPermission()` after the ATT prompt.
6. In every VC: `AnalyticsManager.shared.logScreen(FirebaseEvents.Screen.x)` in `viewDidAppear`.
7. Every button: one tap event. Every plain alert: its own OK event.
8. Every feature: one `_ok` event and one `_fail_<reason>` per error case.
9. IAP: `IAPFlowManager.present(from:event:)` with an `iap_open_*` entry; `IAPTracker.screenAppeared(self)` in
   each IAP screen's `viewDidAppear`; call `TrialTracker.process` / `RenewalTracker.process` from the RevenueCat
   customer-info handler.
10. Verify in Xcode console with filter `EVENT_TRACK` and in Firebase DebugView (`-FIRDebugEnabled`).
