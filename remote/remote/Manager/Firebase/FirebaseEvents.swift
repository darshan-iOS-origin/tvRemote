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
        static let voice = "screen_voice"
        static let subscription = "screen_subscription"
        static let freeTrial = "screen_free_trial"
        static let offerSubscription = "screen_offer_subscription"
        static let premiumActivated = "screen_premium_activated"
        static let appIconSheet = "screen_app_icon_sheet"
        static let pairingCodeAlert = "screen_pairing_code_alert"
        static let connectionRequired = "screen_connection_required"
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
    }
}
