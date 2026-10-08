//
//  FavouritesVC.swift
//  remote
//
//  Created by mac on 07/10/26.
//

import UIKit

/// The TVs the user marked with a heart on My TVs. Tapping a heart here takes the TV off the list.
class FavouritesVC: UIViewController {

    private let store = UserDefaultsDeviceStore()
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIStackView()

    private var tvs: [SavedTV] = []

    /// Connects a tapped TV, pairing first if it needs it. Afterwards the Remote tab opens.
    private lazy var connector: TVConnector = {
        let connector = TVConnector(presenter: self)
        connector.onConnected = { [weak self] in self?.tabBarController?.selectedIndex = 0 }
        return connector
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: - Layout

    private func setupViews() {
        titleLabel.text = "Favourites"
        titleLabel.font = CommonFont.heavy.font(ofSize: 24)
        titleLabel.textColor = CommonColor.white.color

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        // Room under the last row for the floating tab bar.
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 110, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(FavouriteCell.self)

        let image = UIImageView(image: UIImage(named: "empty_heart"))
        image.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "No Favourites Yet"
        title.font = CommonFont.bold.font(ofSize: 20)
        title.textColor = CommonColor.white.color
        title.textAlignment = .center
        let message = UILabel()
        message.text = "Add your favorites TVs to access them quickly and easily."
        message.font = CommonFont.medium.font(ofSize: 14)
        message.textColor = CommonColor.secondaryGray.color
        message.textAlignment = .center
        message.numberOfLines = 0
        [image, title, message].forEach { emptyView.addArrangedSubview($0) }
        emptyView.axis = .vertical
        emptyView.alignment = .center
        emptyView.spacing = 12
        emptyView.setCustomSpacing(16, after: image)

        [titleLabel, tableView, emptyView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 6),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
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
        tvs = store.load()
            .filter { $0.isFavorite == true }
            .sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
        tableView.isHidden = tvs.isEmpty
        emptyView.isHidden = !tvs.isEmpty
        tableView.reloadData()
    }

    /// Connecting drops the TV that is connected now, so say so first.
    private func connect(to tv: SavedTV) {
        Task { [weak self] in
            let current = await AppServices.connection.activeDevice
            guard let self else { return }
            guard let current else {
                self.connector.connect(to: tv.device)
                return
            }
            // Already connected to this one: nothing to do.
            guard current.host != tv.host else { return }
            let alert = UIAlertController(
                title: "Connect to \(tv.device.name)?",
                message: "\"\(current.name)\" will be disconnected. Do you want to continue?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Connect", style: .default) { [weak self] _ in
                self?.connector.connect(to: tv.device)
            })
            self.present(alert, animated: true)
        }
    }

    private func unfavorite(_ tv: SavedTV) {
        store.setFavorite(host: tv.host, isFavorite: false)
        reload()
    }
}

extension FavouritesVC: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tvs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(FavouriteCell.self, for: indexPath)
        let tv = tvs[indexPath.row]
        cell.configure(with: tv) { [weak self] in self?.unfavorite(tv) }
        return cell
    }
}

extension FavouritesVC: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tvs.indices.contains(indexPath.row) else { return }
        connect(to: tvs[indexPath.row])
    }
}
