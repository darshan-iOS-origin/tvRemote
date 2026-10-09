import UIKit

/// What the three subscription screens share: buying a plan, restoring, the legal links, and the
/// "Premium Activated!" screen. Each screen only says what happens afterwards.
extension UIViewController {

    /// Buys `plan` with a loader over the screen. A cancelled payment sheet does nothing; a failure shows an
    /// alert; a success shows "Premium Activated!" and then runs `onSuccess`.
    func startPurchase(of plan: SubscriptionProduct, onSuccess: @escaping () -> Void) {
        LoaderView.show(message: "Processing purchase…")
        Task { [weak self] in
            do {
                let outcome = try await SubscriptionManager.shared.purchase(plan)
                LoaderView.hide()
                if outcome == .purchased {
                    self?.showPremiumActivated(onDone: onSuccess)
                }
            } catch {
                LoaderView.hide()
                HapticManager.trigger(.error)
                self?.showSimpleAlert(title: "Purchase Failed", message: SubscriptionManager.shared.userMessage(for: error))
            }
        }
    }

    /// Restores earlier purchases with a loader. Shows "Premium Activated!" if that unlocked Premium.
    func startRestore(onSuccess: @escaping () -> Void) {
        LoaderView.show(message: "Restoring purchases…")
        Task { [weak self] in
            do {
                let isPremium = try await SubscriptionManager.shared.restore()
                LoaderView.hide()
                if isPremium {
                    self?.showPremiumActivated(onDone: onSuccess)
                } else {
                    self?.showSimpleAlert(title: "Nothing to Restore", message: "No active subscription was found for this Apple ID.")
                }
            } catch {
                LoaderView.hide()
                HapticManager.trigger(.error)
                self?.showSimpleAlert(title: "Restore Failed", message: SubscriptionManager.shared.userMessage(for: error))
            }
        }
    }

    /// The "Premium Activated!" dialog; `onDone` runs when the user taps Start Using Premium.
    func showPremiumActivated(onDone: @escaping () -> Void) {
        HapticManager.trigger(.success)
        let activated = PremiumActivatedVC()
        activated.onDone = onDone
        present(activated, animated: true)
    }

    /// "Privacy Policy", "Restore Purchase" and "Terms of Service" as small underlined links, wired up.
    /// `onRestored` runs after a restore that unlocked Premium (once "Premium Activated!" is done).
    func makeLegalLinks(onRestored: @escaping () -> Void) -> UIStackView {
        func link(_ title: String, action: @escaping () -> Void) -> UIButton {
            let button = HapticButton(type: .custom)
            button.setAttributedTitle(NSAttributedString(string: title, attributes: [
                .font: CommonFont.medium.font(ofSize: 11),
                .foregroundColor: UIColor(hex: 0x707A91),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]), for: .normal)
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return button
        }
        let links = UIStackView(arrangedSubviews: [
            link("Privacy Policy") { Self.openLegal(AppConfig.privacyPolicyURL) },
            link("Restore Purchase") { [weak self] in self?.startRestore(onSuccess: onRestored) },
            link("Terms of Service") { Self.openLegal(AppConfig.termsOfServiceURL) }
        ])
        links.distribution = .equalSpacing
        return links
    }

    private static func openLegal(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}
