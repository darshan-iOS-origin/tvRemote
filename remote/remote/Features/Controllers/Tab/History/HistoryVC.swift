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

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        statusTask?.cancel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
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

    // MARK: - Data

    private func reload() {
        tvs = store.load().sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
        tableView.isHidden = tvs.isEmpty
        emptyView.isHidden = !tvs.isEmpty
        tableView.reloadData()
        refreshStatus()
    }

    /// Checks every TV at once. The connected one is online without a probe.
    private func refreshStatus() {
        statusTask?.cancel()
        let saved = tvs
        statusTask = Task { [weak self] in
            let activeHost = await AppServices.connection.activeDevice?.host
            await withTaskGroup(of: (String, Bool).self) { group in
                for tv in saved {
                    group.addTask {
                        if tv.host == activeHost { return (tv.host, true) }
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
        cell.configure(with: tvs[row], isOnline: isOnline)
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    private func setDefault(_ tv: SavedTV) {
        store.setDefault(host: tv.host, isDefault: true)
        reload()
    }

    private func rename(_ tv: SavedTV) {
        let dialog = RenameAlertVC(currentName: tv.device.name)
        dialog.onRename = { [weak self] name in
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tvs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(HistoryCell.self, for: indexPath)
        let tv = tvs[indexPath.row]
        cell.configure(with: tv, isOnline: online[tv.host])
        return cell
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        guard tvs.indices.contains(indexPath.row) else { return nil }
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
