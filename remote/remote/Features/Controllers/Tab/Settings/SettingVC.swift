//
//  SettingVC.swift
//  remote
//
//  Created by mac on 07/10/26.
//

import UIKit

/// The Settings tab: the "App Settings" title (storyboard), then in one vertical stack the PRO banner and
/// the General and Help cards. The banner is a stack item, so hiding it for a premium user closes the gap.
class SettingVC: UIViewController {

    private let sideMargin: CGFloat = 16
    /// Below the storyboard title labels (6pt top + 28pt tall), plus a gap.
    private let titleClearance: CGFloat = TabHeader.height
    /// Space under the last card. The scroll view adds the tab bar's height on its own (safe area), so this is
    /// only the gap above the tab bar.
    private let tabBarClearance: CGFloat = 16

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let proBanner = UIImageView(image: UIImage(named: "pro_banner"))

    override func viewDidLoad() {
        super.viewDidLoad()
        scalePadFonts()
        applyGradientBackground()
        buildLayout()
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateProBanner), name: SubscriptionManager.didChangeNotification, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateProBanner()
    }

    /// The PRO banner is for free users only; it goes away the moment Premium turns on.
    @objc private func updateProBanner() {
        proBanner.isHidden = SubscriptionManager.shared.isPremium
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset.bottom = tabBarClearance
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor, constant: titleClearance),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: sideMargin),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -sideMargin)
        ])

        proBanner.contentMode = .scaleAspectFit
        proBanner.isUserInteractionEnabled = true
        proBanner.accessibilityLabel = "TV Remote PRO"
        proBanner.accessibilityTraits = .button
        proBanner.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_proBanner)))
        proBanner.heightAnchor.constraint(equalTo: proBanner.widthAnchor, multiplier: 90.0 / 353.0).isActive = true

        contentStack.addArrangedSubview(proBanner)
        contentStack.addArrangedSubview(makeSection(title: "General", rows: [
            SettingRowView(iconName: "ic_changeIcons", title: "Change Icon", accessory: .chevron, onTap: { [weak self] in
                NavigationManager.shared.showAppIcon(from: self?.navigationController)
            }),
            // No shirt icon in the asset catalog yet: add one named "ic_theme" and it replaces the symbol.
            SettingRowView(iconName: "ic_theme", fallbackSymbol: "tshirt", title: "App Theme", accessory: .chevron, onTap: { [weak self] in
                NavigationManager.shared.showAppTheme(from: self?.navigationController)
            })
        ]))
        contentStack.addArrangedSubview(makeSection(title: "Help", rows: [
            SettingRowView(iconName: "ic_share", title: "Share App", accessory: .chevron, onTap: { [weak self] in
                self?.shareApp()
            }),
            SettingRowView(iconName: "ic_rateus", title: "Rate App", accessory: .chevron, onTap: { [weak self] in
                self?.requestReview()
            }),
            SettingRowView(iconName: "ic_feedback", title: "Feedback", accessory: .chevron, onTap: { [weak self] in
                NavigationManager.shared.showFeedback(from: self?.navigationController)
            }),
            SettingRowView(iconName: "ic_privacy", title: "Privacy Policy", accessory: .chevron),
            SettingRowView(iconName: "ic_version", title: "Version", accessory: .value(Self.appVersion))
        ]))
    }

    /// A muted header over a rounded card that holds the rows.
    private func makeSection(title: String, rows: [SettingRowView]) -> UIView {
        let header = UILabel()
        header.text = title
        header.font = CommonFont.semibold.font(ofSize: 16)
        header.textColor = CommonColor.secondaryGray.color

        let card = UIView()
        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1.5
        card.layer.borderColor = UIColor(hex: 0x202A40).cgColor

        let rowStack = UIStackView(arrangedSubviews: rows)
        rowStack.axis = .vertical
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])

        let section = UIStackView(arrangedSubviews: [header, card])
        section.axis = .vertical
        section.spacing = 12
        return section
    }

    // MARK: - Actions

    @objc private func onTap_proBanner() {
        HapticManager.trigger(.light)
        NavigationManager.shared.showSubscription(from: self)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Opens the App Store's "Write a Review" screen for the app.
    private func requestReview() {
        guard let url = AppConfig.writeReviewURL else { return }
        UIApplication.shared.open(url)
    }

    /// The share sheet with the app's App Store link.
    private func shareApp() {
        guard let url = AppConfig.appStoreURL else { return }
        let sheet = UIActivityViewController(activityItems: ["Control your TV from your phone with \(FeedbackMail.appName)", url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(sheet, animated: true)
    }
}
