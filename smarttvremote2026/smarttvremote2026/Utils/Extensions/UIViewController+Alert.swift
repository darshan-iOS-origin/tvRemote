import UIKit

extension UIViewController {

    /// A plain system alert with one OK button.
    /// `okEvent` is required so every alert has its own analytics event.
    func showSimpleAlert(title: String, message: String, okEvent: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            AnalyticsManager.shared.log(okEvent)
            completion?()
        })
        present(alert, animated: true)
    }
}
