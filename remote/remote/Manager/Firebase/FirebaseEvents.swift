/// Every custom Firebase Analytics event name lives here.
///
/// Add new events as constants below. Names must be 35 characters or fewer
/// (this app's limit; Firebase allows 40), use letters, digits and underscores,
/// and start with a letter. `AnalyticsManager` drops any name that breaks these rules.
enum FirebaseEvents {

    /// Longest event name this app sends.
    static let maxNameLength = 35

    // MARK: - App lifecycle

    /// The app process launched from a terminated state.
    static let appColdStart = "app_cold_start"

    // MARK: - Screens

    /// One event per view controller, logged each time it appears.
    enum Screen {
        static let splash = "screen_splash"
        /// Onboarding pager pages, in order: the two intro pages, then brand selection.
        static let onboardingPages = ["screen_onboarding_1", "screen_onboarding_2", "screen_onboarding_3"]
        static let scanning = "screen_scanning"
        static let remote = "screen_remote"
        static let cast = "screen_cast"
        static let mirroring = "screen_mirroring"
        static let keyboard = "screen_keyboard"
        static let myApps = "screen_my_apps"
        static let addApps = "screen_add_apps"
        static let favourites = "screen_favourites"
        static let history = "screen_history"
        static let myTVs = "screen_my_tvs"
        static let settings = "screen_settings"
        static let appTheme = "screen_app_theme"
        static let appIcon = "screen_app_icon"
        static let feedback = "screen_feedback"
        static let manageSubscription = "screen_manage_subscription"
        static let voice = "screen_voice"
        static let subscription = "screen_subscription"
        static let freeTrial = "screen_free_trial"
        static let offerSubscription = "screen_offer_subscription"
        static let premiumActivated = "screen_premium_activated"
        static let appIconSheet = "screen_app_icon_sheet"
        static let pairingCodeAlert = "screen_pairing_code_alert"
        static let connectionRequired = "screen_connection_required"
        static let noInternetAlert = "screen_no_internet_alert"
        static let magicCursorAlert = "screen_magic_cursor_alert"
        static let textInputAlert = "screen_text_input_alert"
    }

    // MARK: - Permissions

    /// System permission alerts: `<permission>_permission_trigger|allowed|deny`, and the app's own
    /// "open Settings" alerts shown after a denial. Each system event is logged once per install,
    /// and only when the system alert was really shown.
    enum Permission {

        struct Events {
            let trigger: String
            let allowed: String
            let deny: String
        }

        static let tracking = Events(
            trigger: "att_permission_trigger", allowed: "att_permission_allowed", deny: "att_permission_deny")
        static let notifications = Events(
            trigger: "notification_permission_trigger", allowed: "notification_permission_allowed",
            deny: "notification_permission_deny")
        static let microphone = Events(
            trigger: "mic_permission_trigger", allowed: "mic_permission_allowed", deny: "mic_permission_deny")
        static let speech = Events(
            trigger: "speech_permission_trigger", allowed: "speech_permission_allowed",
            deny: "speech_permission_deny")
        static let localNetwork = Events(
            trigger: "local_network_permission_trigger", allowed: "local_network_permission_allowed",
            deny: "local_network_permission_deny")

        /// The events for a permission, by the name `PermissionLogger` uses.
        static func events(for name: String) -> Events? {
            switch name {
            case "Tracking": return tracking
            case "Notifications": return notifications
            case "Microphone": return microphone
            case "Speech Recognition": return speech
            case "Local Network": return localNetwork
            default: return nil
            }
        }

        // The app's own alert that sends the user to Settings after a denial.
        static let localNetworkSettingsAlert = "local_network_settings_alert"
        static let localNetworkSettingsOpen = "local_network_settings_open"
        static let voiceSettingsAlert = "voice_settings_alert"
        static let voiceSettingsOpen = "voice_settings_open"
        static let localNetworkSettingsCancel = "local_network_settings_cancel"
        static let voiceSettingsCancel = "voice_settings_cancel"
        static let castSettingsAlert = "cast_settings_alert"
        static let castSettingsOpen = "cast_settings_open"
        static let castSettingsCancel = "cast_settings_cancel"
        static let notificationSettingsAlert = "notification_settings_alert"
        static let notificationSettingsOpen = "notification_settings_open"
        static let notificationSettingsCancel = "notification_settings_cancel"
    }

    // MARK: - IAP entry points

    /// What opened the IAP (subscription) screen: one event per button or view. Logged each time the
    /// screen really opens.
    enum IAPEntry {
        static let settingProBanner = "iap_open_setting_banner"
        static let remoteLimit = "iap_open_remote_limit"
        static let keyboardLimit = "iap_open_keyboard_limit"
        static let mirrorLimit = "iap_open_mirror_limit"
        static let mirrorQuality = "iap_open_mirror_quality"
        static let castLimit = "iap_open_cast_limit"
        static let addTVLimit = "iap_open_add_tv_limit"
        static let historyLockedTV = "iap_open_history_locked_tv"
        static let myTVsFavorite = "iap_open_my_tvs_favorite"
        static let appThemeLocked = "iap_open_app_theme_locked"
        static let appIconSheet = "iap_open_app_icon_sheet"
        static let splash = "iap_open_splash"
        static let scanning = "iap_open_scanning"
        /// The special offer that opens when a free user taps "Expensive" on the Manage Subscription screen.
        static let manageSub = "iap_open_manage_sub"
    }

    // MARK: - Button and view taps

    /// One event per button or tappable view: `<screen>_<element>_tap`. Logged on every tap, no parameters.
    enum Tap {
        // Onboarding
        /// The Continue button on each onboarding page, in page order.
        static let onboardingContinue = ["onboarding_1_continue_tap", "onboarding_2_continue_tap", "onboarding_3_continue_tap"]
        /// The brand tiles, by the tile's image name (`BrandOption.id`).
        static let onboardingBrand: [String: String] = [
            "roku": "onboarding_brand_roku_tap",
            "samsung": "onboarding_brand_samsung_tap",
            "lg": "onboarding_brand_lg_tap",
            "sony": "onboarding_brand_sony_tap",
            "vizio": "onboarding_brand_vizio_tap",
            "firetvGoogle": "onboarding_brand_android_tv_tap",
            "fire": "onboarding_brand_fire_tv_tap",
            "other": "onboarding_brand_other_tap"
        ]

        // Scanning
        static let scanningClose = "scanning_close_tap"
        static let scanningRescan = "scanning_rescan_tap"
        static let scanningTV = "scanning_tv_tap"
        static let scanningNoTVRescan = "scanning_notv_rescan_tap"
        static let scanningNoTVOkay = "scanning_notv_okay_tap"

        // Pairing code dialog
        static let pairingPair = "pairing_pair_tap"
        static let pairingCancel = "pairing_cancel_tap"

        // Tab bar, in tab order
        static let tabBar = ["tab_remote_tap", "tab_apps_tap", "tab_keyboard_tap", "tab_favourites_tap", "tab_settings_tap"]

        // Remote tab
        static let remoteKeyboard = "remote_keyboard_tap"
        static let remoteHistory = "remote_history_tap"
        static let remoteAddTV = "remote_add_tv_tap"
        /// The Remote tab's mode switch: Buttons, Touchpad, LG Remote.
        static let remoteSegments = ["remote_seg_buttons_tap", "remote_seg_touchpad_tap", "remote_seg_lg_tap"]
        static let remoteCast = "remote_cast_tap"
        static let remoteVoice = "remote_voice_tap"
        static let remoteMirror = "remote_mirror_tap"
        static let remotePadOK = "remote_pad_ok_tap"
        static let remoteCursor = "remote_cursor_tap"
        static let remoteCursorGotIt = "remote_cursor_gotit_tap"
        static let remoteCursorClick = "remote_cursor_click_tap"
        /// The transport row's play button; the Playback card is `remote_play_pause_tap`.
        static let remotePlay = "remote_play_tap"
        static let remotePlayPause = "remote_play_pause_tap"

        /// Remote and Keyboard keys by `KeyCommand.rawValue`. `playPause` is set by hand (two buttons send it).
        static let keys: [String: String] = [
            "power": "remote_power_tap",
            "up": "remote_up_tap", "down": "remote_down_tap", "left": "remote_left_tap", "right": "remote_right_tap",
            "select": "remote_ok_tap",
            "volumeUp": "remote_vol_up_tap", "volumeDown": "remote_vol_down_tap",
            "channelUp": "remote_ch_up_tap", "channelDown": "remote_ch_down_tap",
            "previous": "remote_prev_tap", "next": "remote_next_tap", "stop": "remote_stop_tap",
            "liveTV": "remote_live_tv_tap", "input": "remote_input_tap",
            "back": "remote_back_tap", "home": "remote_home_tap", "menu": "remote_menu_tap", "info": "remote_info_tap", "settings": "remote_settings_tap",
            "hdmi1": "remote_hdmi_1_tap", "hdmi2": "remote_hdmi_2_tap", "hdmi3": "remote_hdmi_3_tap", "hdmi4": "remote_hdmi_4_tap",
            "rewind": "remote_rewind_tap", "fastForward": "remote_forward_tap",
            "red": "remote_red_tap", "green": "remote_green_tap", "yellow": "remote_yellow_tap", "blue": "remote_blue_tap",
            "subtitles": "remote_subtitle_tap",
            "digit0": "keyboard_digit_0_tap", "digit1": "keyboard_digit_1_tap", "digit2": "keyboard_digit_2_tap",
            "digit3": "keyboard_digit_3_tap", "digit4": "keyboard_digit_4_tap", "digit5": "keyboard_digit_5_tap",
            "digit6": "keyboard_digit_6_tap", "digit7": "keyboard_digit_7_tap", "digit8": "keyboard_digit_8_tap",
            "digit9": "keyboard_digit_9_tap"
        ]

        // Keyboard tab
        static let keyboardText = "keyboard_text_tap"
        static let keyboardHistory = "keyboard_history_tap"
        static let keyboardAddTV = "keyboard_add_tv_tap"
        static let keyboardBackspace = "keyboard_backspace_tap"

        // My Apps tab and Add Apps screen (one event per app: `myapps_app_<id>_tap`, `addapps_app_<id>_tap`)
        static let myAppsAdd = "myapps_add_tap"
        static let myAppsAddMore = "myapps_add_more_tap"
        static func myAppsApp(_ id: String) -> String { "myapps_app_\(id)_tap" }
        static let addAppsBack = "addapps_back_tap"
        static let addAppsAdd = "addapps_add_tap"
        static func addAppsApp(_ id: String) -> String { "addapps_app_\(id)_tap" }

        // Favourites tab
        static let favouritesTV = "favourites_tv_tap"
        static let favouritesHeart = "favourites_heart_tap"
        static let favouritesConnect = "favourites_connect_tap"
        static let favouritesCancel = "favourites_cancel_tap"

        // Settings tab
        static let settingChangeIcon = "setting_change_icon_tap"
        static let settingAppTheme = "setting_app_theme_tap"
        static let settingShare = "setting_share_tap"
        static let settingRate = "setting_rate_tap"
        static let settingManageSubscription = "setting_manage_subscription_tap"
        static let settingFeedback = "setting_feedback_tap"
        static let settingPrivacy = "setting_privacy_tap"

        // Cast screen
        static let castBack = "cast_back_tap"
        static let castPhoto = "cast_photo_tap"
        static let castVideo = "cast_video_tap"
        static let castFiles = "cast_files_tap"
        static let castPrev = "cast_prev_tap"
        static let castPlayPause = "cast_play_pause_tap"
        static let castNext = "cast_next_tap"
        static let castStop = "cast_stop_tap"
        /// The user let go of the progress bar after dragging it.
        static let castSeek = "cast_seek_tap"

        // Screen Mirroring
        static let mirrorBack = "mirror_back_tap"
        /// Smart TV, Web.
        static let mirrorSegments = ["mirror_seg_smart_tv_tap", "mirror_seg_web_tap"]
        static let mirrorPrimary = "mirror_primary_tap"
        static let mirrorQuality: [String: String] = [
            "p480": "mirror_480p_tap", "p720": "mirror_720p_tap", "p1080": "mirror_1080p_tap"
        ]
        static let mirrorCopy = "mirror_copy_tap"
        static let mirrorShare = "mirror_share_tap"

        // History screen
        static let historyBack = "history_back_tap"
        static let historyTV = "history_tv_tap"
        static let historyDefault = "history_default_tap"
        static let historyRename = "history_rename_tap"
        static let historyDelete = "history_delete_tap"
        static let historyDeleteOK = "history_delete_ok_tap"
        static let historyDeleteCancel = "history_delete_cancel_tap"
        static let historyRenameOK = "history_rename_ok_tap"
        static let historyRenameCancel = "history_rename_cancel_tap"

        // My TVs screen
        static let myTVsBack = "mytvs_back_tap"
        static let myTVsAdd = "mytvs_add_tap"
        static let myTVsHeart = "mytvs_heart_tap"
        static let myTVsConnect = "mytvs_connect_tap"
        static let myTVsDisconnect = "mytvs_disconnect_tap"
        static let myTVsScanOK = "mytvs_scan_ok_tap"
        static let myTVsScanCancel = "mytvs_scan_cancel_tap"

        // Voice screen
        static let voiceBack = "voice_back_tap"
        static let voiceMic = "voice_mic_tap"

        // App Theme screen
        static let appThemeBack = "apptheme_back_tap"
        static let appThemeApply = "apptheme_apply_tap"
        /// `apptheme_<n>_tap`, n = 1...6.
        static func appTheme(_ index: Int) -> String { "apptheme_\(index + 1)_tap" }

        // App Icon screen and sheet
        static let appIconBack = "appicon_back_tap"
        static let appIconApply = "appicon_apply_tap"
        static let appIconSheetPremium = "appicon_sheet_premium_tap"
        static let appIconSheetClose = "appicon_sheet_close_tap"
        /// `appicon_<id>_tap`, id = 1...6.
        static func appIcon(_ id: Int) -> String { "appicon_\(id)_tap" }

        // Feedback screen
        static let feedbackBack = "feedback_back_tap"
        static let feedbackSend = "feedback_send_tap"
        static let feedbackReasons: [String: String] = [
            "Not Good": "feedback_not_good_tap",
            "App Crashes": "feedback_crashes_tap",
            "Very Poor": "feedback_poor_tap",
            "Slow Experience": "feedback_slow_tap",
            "Too Difficult": "feedback_difficult_tap",
            "Excellent": "feedback_excellent_tap",
            "Disappointing": "feedback_disappointing_tap",
            "Other": "feedback_other_tap"
        ]

        // Manage Subscription screen
        static let manageSubBack = "managesub_back_tap"
        static let manageSubReasons: [String: String] = [
            "Expensive": "managesub_expensive_tap",
            "App Crash": "managesub_crash_tap",
            "Feature Not Working": "managesub_not_working_tap",
            "Found a cheaper alternative": "managesub_cheaper_tap",
            "Too complicated": "managesub_complicated_tap",
            "Keep Current Plan": "managesub_keep_tap"
        ]
        static let manageSubCancel = "managesub_cancel_tap"
        static let manageSubMailSent = "managesub_mail_sent_tap"
        static let manageSubMailCancel = "managesub_mail_cancel_tap"

        // Shared dialogs
        static let typeTVSend = "typetv_send_tap"
        static let typeTVCancel = "typetv_cancel_tap"
        static let connectAlertConnect = "connect_alert_connect_tap"
        static let connectAlertLater = "connect_alert_later_tap"
        static let noInternetRetry = "no_internet_retry_tap"
        static let noInternetClose = "no_internet_close_tap"
        static let premiumStart = "premium_start_tap"

        // OK button of each plain alert (`showSimpleAlert`), one event per alert
        static let appIconAlertOK = "appicon_alert_ok_tap"
        static let appThemeAlertOK = "apptheme_alert_ok_tap"
        static let feedbackPickAlertOK = "feedback_pick_alert_ok_tap"
        static let feedbackOtherAlertOK = "feedback_other_alert_ok_tap"
        static let myAppsNotFoundAlertOK = "myapps_na_alert_ok_tap"
        static let myAppsErrorAlertOK = "myapps_error_alert_ok_tap"
        static let keyboardAlertOK = "keyboard_alert_ok_tap"
        static let remoteAlertOK = "remote_alert_ok_tap"
        static let voiceNotConnectedAlertOK = "voice_noconn_alert_ok_tap"
        static let voiceUnsupportedAlertOK = "voice_unsupported_alert_ok_tap"
        static let voiceErrorAlertOK = "voice_error_alert_ok_tap"
        /// Taps that belong to the IAP flow but go through shared code; also sent to Clarity.
        static let clarityTaps: Set<String> = [premiumStart, purchaseFailedAlertOK, restoreNoneAlertOK, restoreFailedAlertOK]

        // Closing a system sheet or picker without finishing
        static let mirrorShareCancel = "mirror_share_cancel_tap"
        static let settingShareCancel = "setting_share_cancel_tap"
        static let castPhotoCancel = "cast_photo_cancel_tap"
        static let castFilesCancel = "cast_files_cancel_tap"
        static let feedbackMailSent = "feedback_mail_sent_tap"
        static let feedbackMailCancel = "feedback_mail_cancel_tap"

        static let castAlertOK = "cast_alert_ok_tap"
        static let scanPortAlertOK = "scan_port_alert_ok_tap"
        static let scanAddressAlertOK = "scan_address_alert_ok_tap"
        static let scanNoTVAlertOK = "scan_notv_alert_ok_tap"
        static let connectFailedAlertOK = "connect_fail_alert_ok_tap"
        static let mailSetupAlertOK = "mail_setup_alert_ok_tap"
        static let feedbackSentAlertDone = "feedback_sent_alert_done_tap"
        static let purchaseFailedAlertOK = "iap_buy_fail_alert_ok_tap"
        static let restoreNoneAlertOK = "iap_restore_none_ok_tap"
        static let restoreFailedAlertOK = "iap_restore_fail_ok_tap"
    }

    // MARK: - Feature results

    /// Success and fail events. Each fail event names its reason; the `...Fail(for:)` functions pick it
    /// from the error so call sites never build names. A nil result means "no event for this error".
    enum Outcome {

        // Scan
        static let scanFoundTV = "scan_found_tv"
        static let scanFoundNone = "scan_found_none"

        // Connect to a TV
        static let connectOK = "connect_ok"
        static let connectFailOther = "connect_fail_other"
        static func connectFail(for error: Error) -> String {
            switch error as? TVError {
            case .unreachable?: return "connect_fail_unreachable"
            case .timedOut?: return "connect_fail_timeout"
            case .refused?: return "connect_fail_refused"
            case .denied?: return "connect_fail_denied"
            case .awaitingApproval?: return "connect_fail_noapprove"
            case .notPaired?: return "connect_fail_notpaired"
            case nil: return error is CancellationError ? connectFailOther : "connect_fail_unreachable"
            default: return connectFailOther
            }
        }

        // Pairing code
        static let pairCodeOK = "pair_code_ok"
        static let pairCodeWrong = "pair_code_wrong"
        static let pairFailUnsupported = "pair_fail_unsupported"
        static func pairFail(for error: PairingError) -> String {
            switch error {
            case .unreachable: return "pair_fail_unreachable"
            case .timedOut: return "pair_fail_timeout"
            case .alreadyPending: return "pair_fail_pending"
            case .rejected: return "pair_fail_rejected"
            case .badResponse: return "pair_fail_badresp"
            case .identityUnavailable: return "pair_fail_identity"
            case .wrongCode: return pairCodeWrong
            case .notBuilt: return pairFailUnsupported
            }
        }

        // Add TV by IP
        static let connectManualOK = "connect_manual_ok"
        static let connectManualNoLocal = "connect_manual_nolocal"
        static let connectManualNoPort = "connect_manual_noport"
        static let connectManualNoAnswer = "connect_manual_noanswer"

        // Remote keys
        static func remoteFail(for error: Error) -> String {
            switch error as? TVError {
            case .timedOut?: return "remote_fail_timeout"
            case .refused?: return "remote_fail_refused"
            case .denied?: return "remote_fail_denied"
            case .notPaired?: return "remote_fail_notpaired"
            case .unsupportedKey?: return "remote_fail_nokey"
            default: return "remote_fail_unreachable"
            }
        }

        // Keyboard tab digits
        static func keyboardFail(for error: Error) -> String {
            switch error as? TVError {
            case .timedOut?: return "keyboard_fail_timeout"
            case .refused?: return "keyboard_fail_refused"
            case .denied?: return "keyboard_fail_denied"
            case .notPaired?: return "keyboard_fail_notpaired"
            default: return "keyboard_fail_unreachable"
            }
        }

        // Type on TV
        static let typeTVOK = "typetv_ok"
        static func typeTVFail(for error: Error) -> String {
            switch error as? TVError {
            case .unreachable?, nil: return "typetv_fail_unreachable"
            case .timedOut?: return "typetv_fail_timeout"
            case .unsupportedText?, .unsupportedCharacter?: return "typetv_fail_unsupported"
            default: return "typetv_fail_other"
            }
        }

        // Voice
        static let voiceOK = "voice_ok"
        static func voiceFail(for error: Error) -> String {
            switch error as? VoiceAssistantError {
            case .microphoneDenied?: return "voice_fail_mic_denied"
            case .speechDenied?: return "voice_fail_speech_denied"
            case .onDeviceUnavailable?: return "voice_fail_nomodel"
            case .microphoneUnavailable?: return "voice_fail_mic_error"
            case .nothingHeard?: return "voice_fail_nothing_heard"
            case nil: return "voice_fail_other"
            }
        }

        // My Apps launch
        static let myAppsLaunchOK = "myapps_launch_ok"
        static let myAppsNotOnTV = "myapps_fail_not_on_tv"
        static func myAppsFail(for error: Error) -> String {
            switch error as? TVError {
            case .unreachable?, nil: return "myapps_fail_unreachable"
            case .timedOut?: return "myapps_fail_timeout"
            case .refused?: return "myapps_fail_refused"
            default: return "myapps_fail_other"
            }
        }

        // Cast
        static let castPlayOK = "cast_play_ok"
        static let castSeekOK = "cast_seek_ok"
        static func castSeekFail(for error: Error) -> String {
            switch error as? TVError {
            case .unsupportedCasting?: return "cast_seek_fail_unsupported"
            case .timedOut?: return "cast_seek_fail_timeout"
            case .notConnected?: return "cast_seek_fail_notconnected"
            default: return "cast_seek_fail_other"
            }
        }
        static func castFail(for error: Error) -> String? {
            switch error {
            case let failure as CastFailure:
                switch failure {
                case .notConnected: return nil
                case .localNetworkDenied: return "cast_fail_localnet"
                case .fileTooLarge: return "cast_fail_toolarge"
                }
            case let media as CastMediaError:
                switch media {
                case .noWiFi: return "cast_fail_nowifi"
                case .serverFailed: return "cast_fail_server"
                case .preparationFailed: return "cast_fail_prepare"
                }
            case let tv as TVError:
                switch tv {
                case .timedOut: return "cast_fail_tv_timeout"
                case .unsupportedCasting: return "cast_fail_tv_unsupported"
                case .castFailed: return "cast_fail_tv_format"
                default: return "cast_fail_tv_unreachable"
                }
            default: return "cast_fail_tv_unreachable"
            }
        }

        // Screen Mirror
        static let mirrorTVOK = "mirror_tv_ok"
        static let mirrorWebOK = "mirror_web_ok"
        static func mirrorFail(for error: Error) -> String? {
            switch error {
            case let failure as CastFailure:
                return failure == .localNetworkDenied ? "mirror_fail_localnet" : nil
            case let media as CastMediaError:
                return media == .noWiFi ? "mirror_fail_nowifi" : "mirror_fail_server"
            case let tv as TVError:
                switch tv {
                case .timedOut: return "mirror_fail_tv_timeout"
                case .unsupportedCasting: return "mirror_fail_tv_unsupported"
                case .castFailed: return "mirror_fail_tv_format"
                default: return "mirror_fail_tv_unreachable"
                }
            default: return "mirror_fail_tv_unreachable"
            }
        }

        // Settings and background
        static let appIconOK = "appicon_change_ok"
        static let appIconFailUnsupported = "appicon_fail_unsupported"
        static let appIconFailError = "appicon_fail_error"
        static let appThemeOK = "apptheme_apply_ok"
        static let remoteConfigOK = "rc_fetch_ok"
        static let remoteConfigFail = "rc_fetch_fail"
    }
}
