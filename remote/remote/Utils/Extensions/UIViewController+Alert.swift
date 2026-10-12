import UIKit

extension UIViewController {

    /// A plain system alert with one OK button.
    func showSimpleAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            AnalyticsManager.shared.log(FirebaseEvents.Tap.alertOK)
            completion?()
        })
        present(alert, animated: true)
    }
}
