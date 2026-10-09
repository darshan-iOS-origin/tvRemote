import MessageUI
import UIKit

/// Everything about sending feedback by e-mail, in one place: who it goes to, what the message says, and
/// how it is opened (the Mail composer, or a `mailto:` link when the composer is not available).
enum FeedbackMail {

    /// Where feedback is sent. Change the address here.
    static let recipient = "iosfeedbacks201@gmail.com"

    /// The account name printed under the app name in the message. Change it here.
    static let accountName = "Akash Shiyal"

    /// The app's name, for the subject and the body.
    static var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String) ?? "TV Remote"
    }

    static var subject: String { "Feedback from \(appName)" }

    /// The reasons the user ticked, their own words, and details about the app and the phone.
    static func body(reasons: [String], message: String) -> String {
        var lines: [String] = ["Reasons:"]
        if reasons.isEmpty {
            lines.append("- None selected")
        } else {
            lines.append(contentsOf: reasons.map { "- \($0)" })
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("")
        lines.append("Additional Feedback:")
        lines.append(trimmed.isEmpty ? "- (none provided)" : trimmed)
        lines.append("")
        lines.append(appName)
        lines.append("Account - \(accountName)")
        lines.append("")
        lines.append("Device Details:")
        lines.append(contentsOf: deviceDetailLines())
        return lines.joined(separator: "\n")
    }

    static func deviceDetailLines() -> [String] {
        let device = UIDevice.current
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info?["CFBundleVersion"] as? String ?? "Unknown"
        return [
            "- App Version: \(version) (\(build))",
            "- Device Model: \(deviceModelIdentifier())",
            "- System: \(device.systemName) \(device.systemVersion)",
            "- Locale: \(Locale.current.identifier)"
        ]
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return Mirror(reflecting: systemInfo.machine).children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
    }

    static func mailtoURL(reasons: [String], message: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body(reasons: reasons, message: message))
        ]
        return components.url
    }

    /// Opens the Mail composer from `presenter`; with no Mail account it opens a `mailto:` link; with
    /// neither it shows an alert. `onSent` runs after the message was sent from the composer.
    @MainActor
    static func send(reasons: [String], message: String, from presenter: UIViewController, onSent: (() -> Void)? = nil) {
        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            composer.setToRecipients([recipient])
            composer.setSubject(subject)
            composer.setMessageBody(body(reasons: reasons, message: message), isHTML: false)
            let delegate = ComposerDelegate(onSent: onSent)
            composer.mailComposeDelegate = delegate
            // The composer keeps its delegate weakly: tie the delegate's life to the composer.
            objc_setAssociatedObject(composer, &ComposerDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            presenter.present(composer, animated: true)
        } else if let url = mailtoURL(reasons: reasons, message: message), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            presenter.showSimpleAlert(
                title: "Mail not set up",
                message: "Add a mail account in the Mail app, or write to us at \(recipient)."
            )
        }
    }

    private final class ComposerDelegate: NSObject, MFMailComposeViewControllerDelegate {
        nonisolated(unsafe) static var key: UInt8 = 0
        private let onSent: (() -> Void)?

        init(onSent: (() -> Void)?) {
            self.onSent = onSent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) { [onSent] in
                if result == .sent { onSent?() }
            }
        }
    }
}
