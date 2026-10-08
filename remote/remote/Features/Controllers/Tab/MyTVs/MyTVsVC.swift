import UIKit

/// The TVs the user has connected to, as cards with a connect / disconnect button. Opened from "+" in the
/// remote header. The round "+" at the bottom scans for a new TV, after a warning that it disconnects
/// the current one. Built in code; open it with `NavigationManager.showMyTVs(from:)`.
final class MyTVsVC: UIViewController {

    private let store = UserDefaultsDeviceStore()
    private let backButton = HapticButton(type: .custom)
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let addButton = HapticButton(type: .custom)

    private var tvs: [SavedTV] = []
    private var activeHost: String?

    /// Connects a tapped TV, pairing first if it needs it. Stays on this screen afterwards.
    private lazy var connector: TVConnector = {
        let connector = TVConnector(presenter: self)
        connector.onConnected = { [weak self] in self?.reload() }
        return connector
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        titleLabel.text = "My TVs"
        titleLabel.font = CommonFont.semibold.font(ofSize: 16)
        titleLabel.textColor = CommonColor.white.color

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        // Room under the last card for the floating "+".
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        tableView.dataSource = self
        tableView.registerClass(MyTVCell.self)

        emptyLabel.text = "No TVs yet. Tap + to add one."
        emptyLabel.font = CommonFont.medium.font(ofSize: 14)
        emptyLabel.textColor = CommonColor.secondaryGray.color
        emptyLabel.textAlignment = .center

        addButton.setImage(IconsHelper.image(systemName: "plus", pointSize: 22), for: .normal)
        addButton.tintColor = CommonColor.white.color
        addButton.backgroundColor = UIColor(hex: 0x004BF9)
        addButton.layer.cornerRadius = 30
        addButton.accessibilityLabel = "Add a new TV"
        addButton.addTarget(self, action: #selector(onTap_add), for: .touchUpInside)

        [backButton, titleLabel, tableView, emptyLabel, addButton].forEach {
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

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            addButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    // MARK: - Data

    private func reload() {
        tvs = store.load().sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
        Task { [weak self] in
            let host = await AppServices.connection.activeDevice?.host
            guard let self else { return }
            self.activeHost = host
            self.emptyLabel.isHidden = !self.tvs.isEmpty
            self.tableView.reloadData()
        }
    }

    @objc private func appEnteredForeground() {
        guard view.window != nil else { return }
        reload()
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    private func toggleConnection(of tv: SavedTV) {
        if tv.host == activeHost {
            Task { [weak self] in
                await AppServices.connection.disconnect()
                self?.reload()
            }
        } else {
            connector.connect(to: tv.device)
        }
    }

    /// Scanning drops the current TV, so ask first. With nothing connected there is nothing to lose.
    @objc private func onTap_add() {
        Task { [weak self] in
            let isConnected = await AppServices.connection.activeDevice != nil
            guard let self else { return }
            guard isConnected else {
                self.openScanning()
                return
            }
            let alert = UIAlertController(
                title: "Scan for a new TV?",
                message: "Your current TV will be disconnected when you scan for a new one. Do you want to continue?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Scan", style: .default) { [weak self] _ in
                Task { [weak self] in
                    await AppServices.connection.disconnect()
                    self?.openScanning()
                }
            })
            self.present(alert, animated: true)
        }
    }

    private func openScanning() {
        NavigationManager.shared.showScanning(from: navigationController, addingTV: true)
    }
}

// MARK: - Table

extension MyTVsVC: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tvs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(MyTVCell.self, for: indexPath)
        let tv = tvs[indexPath.row]
        cell.configure(with: tv, isConnected: tv.host == activeHost) { [weak self] in
            self?.toggleConnection(of: tv)
        }
        return cell
    }
}
