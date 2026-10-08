import UIKit

/// One choice on the App Icon screen.
struct AppIconOption: Equatable {
    /// 1...6, the same number as the picture in `Assets.xcassets/app_icons`.
    let id: Int

    /// The picture shown in the app.
    var previewName: String { String(id) }

    /// The icon's name for `setAlternateIconName`. Nil is the app's main icon (`AppIcon`).
    var alternateName: String? { id == AppIconManager.defaultID ? nil : "AppIcon-\(id)" }
}

/// Which icon the app has on the home screen, and changing it. The icon sets live in the asset catalog:
/// `AppIcon` (the default, icon 2) and `AppIcon-1`, `-3`, `-4`, `-5`, `-6`, which the build setting
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` lists. iOS keeps the choice, so nothing is stored here.
@MainActor
enum AppIconManager {

    /// The icon the app ships with.
    static let defaultID = 2

    static let options: [AppIconOption] = (1...6).map { AppIconOption(id: $0) }

    /// The icon in use right now.
    static var current: AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return options.first { $0.alternateName == name } ?? AppIconOption(id: defaultID)
    }

    /// Switches the home-screen icon. iOS shows its own "You have changed the icon" alert.
    /// `completion` gets nil on success, or a message for the user.
    static func apply(_ option: AppIconOption, completion: @escaping (String?) -> Void) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion("This device can't change the app icon.")
            return
        }
        UIApplication.shared.setAlternateIconName(option.alternateName) { error in
            if let error {
                LoggerManager.warning("Changing the app icon failed: \(error.localizedDescription)", category: "Settings")
                completion("The icon could not be changed. Please try again.")
            } else {
                completion(nil)
            }
        }
    }
}
