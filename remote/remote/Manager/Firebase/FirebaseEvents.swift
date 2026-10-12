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
}
