import SafariServices
import UIKit

extension UIViewController {

    /// Opens a web page in the in-app Safari browser, over whatever is on top. Only http and https links open.
    func openInAppSafari(_ url: URL?) {
        guard let url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        var top = self
        while let presented = top.presentedViewController { top = presented }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = CommonColor.primaryBlue.color
        top.present(safari, animated: true)
    }
}
