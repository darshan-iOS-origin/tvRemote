import UIKit

/// Every TV the user has connected to, newest first, with a green / red dot for whether it answers now.
/// Long-press a row to set it as the default, rename it or delete it. Built in code; open it with
/// `NavigationManager.showHistory(from:)`.
final class HistoryVC: UIViewController {

    private let store = UserDefaultsDeviceStore()
    private let backButton = HapticButton(type: .custom)
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIStackView()

    private var tvs: [SavedTV] = []
    /// Online state by host. A host missing from here is still being checked.
    private var online: [String: Bool] = [:]
    private var statusTask: Task<Void, Never>?

    /// One soft blur over everything under the free (first) row, down to the bottom of the screen.
    /// It lets touches through to the list.
    private let lockedBlur = UIVisualEffectView(effect: nil)
    private var blurAnimator: UIViewPropertyAnimator?
    private var lockedBlurTop: NSLayoutConstraint?
    /// 0 is no blur, 1 is the full `.dark` blur.
    private static let blurAmount: CGFloat = 0.2
    /// Reconnects to a tapped TV, pairing again if it needs to. After it connects we go back to the remote.
    private lazy var connector: TVConnector = {
        let connector = TVConnector(presenter: self)
        connector.onConnected = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        return connector
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(premiumChanged),
                                               name: SubscriptionManager.didChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyBlurAmount()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        statusTask?.cancel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
        updateLockedBlur()
    }

    // MARK: - Layout

    private func setupViews() {
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        titleLabel.text = "History"
        titleLabel.font = CommonFont.semibold.font(ofSize: 16)
        titleLabel.textColor = CommonColor.white.color

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(HistoryCell.self)

        let image = UIImageView(image: UIImage(named: "empty_history"))
        image.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "No History Yet"
        title.font = CommonFont.bold.font(ofSize: 20)
        title.textColor = CommonColor.white.color
        title.textAlignment = .center
        let message = UILabel()
        message.text = "No recent activity yet. Start controlling your TV to see it here."
        message.font = CommonFont.medium.font(ofSize: 14)
        message.textColor = CommonColor.secondaryGray.color
        message.textAlignment = .center
        message.numberOfLines = 0
        [image, title, message].forEach { emptyView.addArrangedSubview($0) }
        emptyView.axis = .vertical
        emptyView.alignment = .center
        emptyView.spacing = 12
        emptyView.setCustomSpacing(16, after: image)

        [backButton, titleLabel, tableView, emptyView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        setupLockedBlur()
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            image.widthAnchor.constraint(equalToConstant: 140),
            image.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    // MARK: - Locked blur

    private func setupLockedBlur() {
        lockedBlur.isUserInteractionEnabled = false
        lockedBlur.isHidden = true
        lockedBlur.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(lockedBlur, aboveSubview: tableView)

        let icon = UIImageView(image: UIImage(named: "lock") ?? UIImage(systemName: "lock.fill"))
        icon.tintColor = CommonColor.white.color
        icon.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = "Unlock with Premium"
        label.font = CommonFont.semibold.font(ofSize: 14)
        label.textColor = CommonColor.white.color
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        lockedBlur.contentView.addSubview(stack)

        // A tap on the blurred empty space under the last row also opens the Subscription screen.
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap_list(_:)))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)

        let top = lockedBlur.topAnchor.constraint(equalTo: view.topAnchor)
        lockedBlurTop = top
        NSLayoutConstraint.activate([
            top,
            lockedBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lockedBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lockedBlur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            // The middle of the screen, not of the blurred area.
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // A blur effect has no strength setting: a paused animation to the full effect, held part of the
        // way, gives a lighter one.
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
            self?.lockedBlur.effect = UIBlurEffect(style: .dark)
        }
        animator.pausesOnCompletion = true
        blurAnimator = animator
        applyBlurAmount()

        NotificationCenter.default.addObserver(self, selector: #selector(applyBlurAmount),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func onTap_list(_ gesture: UITapGestureRecognizer) {
        guard !lockedBlur.isHidden, tableView.indexPathForRow(at: gesture.location(in: tableView)) == nil else { return }
        HapticManager.trigger(.light)
        NavigationManager.shared.showSubscription(from: self)
    }

    /// iOS resets a paused animation when the app goes to the background: set the strength again.
    @objc private func applyBlurAmount() {
        blurAnimator?.fractionComplete = Self.blurAmount
    }

    /// Shows the blur from the bottom of the first row to the bottom of the screen, for a user without
    /// Premium who has more than one TV.
    private func updateLockedBlur() {
        let isNeeded = !SubscriptionManager.shared.isPremium && tvs.count > 1
        lockedBlur.isHidden = !isNeeded
        guard isNeeded, let lockedBlurTop else { return }
        let firstRow = tableView.convert(tableView.rectForRow(at: IndexPath(row: 0, section: 0)), to: view)
        let minTop = tableView.frame.minY
        let top = max(firstRow.maxY, minTop)
        if lockedBlurTop.constant != top { lockedBlurTop.constant = top }
    }

    // MARK: - Data

    #if DEBUG
    /// TESTING ONLY: five fake TVs, added after the real ones (never saved), so the blur can be seen.
    /// Remove this block and the `tvs += Self.testTVs` line in `reload()` when done.
    private static let testTVs: [SavedTV] = {
        let samples: [(String, TVBrand, TVPlatform)] = [
            ("Living Room TV", .samsung, .tizen),
            ("Bedroom TV", .lg, .webOS),
            ("Kitchen Roku", .roku, .roku),
            ("Office Android TV", .sony, .bravia),
            ("Guest Room Fire TV", .fireTV, .fireTV)
        ]
        return samples.enumerated().map { index, sample in
            var tv = SavedTV(TVDevice(name: sample.0, brand: sample.1, platform: sample.2, host: "192.168.99.\(index + 10)"))
            // Older than any real TV, newest of the five first.
            tv.lastConnected = Date(timeIntervalSince1970: TimeInterval(1_000_000 - index))
            return tv
        }
    }()
    #endif

    private func reload() {
        tvs = store.load().sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
        #if DEBUG
        tvs += Self.testTVs
        #endif
        tableView.isHidden = tvs.isEmpty
        emptyView.isHidden = !tvs.isEmpty
        tableView.reloadData()
        updateLockedBlur()
        refreshStatus()
    }

    /// Checks every TV at once, the connected one too: a TV that was switched off is still the active
    /// device until a key is sent, so being active does not mean it is online.
    private func refreshStatus() {
        statusTask?.cancel()
        let saved = tvs
        statusTask = Task { [weak self] in
            await withTaskGroup(of: (String, Bool).self) { group in
                for tv in saved {
                    group.addTask {
                        let platform = TVPlatform(rawValue: tv.platform) ?? .unknown
                        return (tv.host, await TVReachability.isOnline(host: tv.host, platform: platform))
                    }
                }
                for await (host, isOnline) in group {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self?.setOnline(isOnline, host: host) }
                }
            }
        }
    }

    private func setOnline(_ isOnline: Bool, host: String) {
        online[host] = isOnline
        guard let row = tvs.firstIndex(where: { $0.host == host }),
              let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? HistoryCell else { return }
        cell.configure(with: tvs[row], isOnline: isOnline, isLocked: isLocked(row: row))
    }

    // MARK: - Actions

    /// Without Premium only the newest TV (the first row) can be seen and used; the rest are blurred.
    private func isLocked(row: Int) -> Bool {
        row > 0 && !SubscriptionManager.shared.isPremium
    }

    /// Bought or restored: show every TV.
    @objc private func premiumChanged() {
        tableView.reloadData()
        updateLockedBlur()
    }

    /// A TV may have been switched on or off while the app was away: check every dot again.
    @objc private func appEnteredForeground() {
        guard view.window != nil else { return }
        refreshStatus()
    }

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    private func setDefault(_ tv: SavedTV) {
        store.setDefault(host: tv.host, isDefault: true)
        reload()
    }

    private func rename(_ tv: SavedTV) {
        let dialog = TextInputAlertVC(currentName: tv.device.name)
        dialog.onSubmit = { [weak self] name in
            self?.store.rename(host: tv.host, to: name)
            self?.reload()
        }
        present(dialog, animated: true)
    }

    private func confirmDelete(_ tv: SavedTV) {
        let alert = UIAlertController(
            title: "Delete TV?",
            message: "\"\(tv.device.name)\" will be removed from your history.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            TVForgetter().forget(host: tv.host)
            self?.reload()
        })
        present(alert, animated: true)
    }
}

// MARK: - Table

extension HistoryVC: UITableViewDataSource, UITableViewDelegate {

    /// Keeps the blur's top edge on the bottom of the first row while the list scrolls.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateLockedBlur()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tvs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(HistoryCell.self, for: indexPath)
        let tv = tvs[indexPath.row]
        cell.configure(with: tv, isOnline: online[tv.host], isLocked: isLocked(row: indexPath.row))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tvs.indices.contains(indexPath.row) else { return }
        HapticManager.trigger(.light)
        guard !isLocked(row: indexPath.row) else {
            NavigationManager.shared.showSubscription(from: self)
            return
        }
        connector.connect(to: tvs[indexPath.row].device)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        guard tvs.indices.contains(indexPath.row), !isLocked(row: indexPath.row) else { return nil }
        let tv = tvs[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let makeDefault = UIAction(title: "Set As Default", image: UIImage(systemName: "star")) { _ in
                self?.setDefault(tv)
            }
            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self?.rename(tv)
            }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { _ in
                self?.confirmDelete(tv)
            }
            return UIMenu(children: [makeDefault, rename, delete])
        }
    }
}
