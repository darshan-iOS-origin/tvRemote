import UIKit

class MyAppsVC: UIViewController {

    @IBOutlet weak var collectionview_apps_list: UICollectionView!
    @IBOutlet weak var view_empty_placeholder: UIView!

    private let store = SavedAppsStore.shared
    private var apps: [StreamingApp] = []

    private let columns: CGFloat = 3
    private let rowSpacing: CGFloat = 24
    /// Side insets stay 0: the collection view is already 16pt in from the safe area.
    private let sectionInsets = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
    private var lastLayoutWidth: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupCollectionView()
        reloadApps()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The gap between tiles depends on the width, so rebuild the layout when the width changes.
        let width = collectionview_apps_list.bounds.width
        guard width != lastLayoutWidth else { return }
        lastLayoutWidth = width
        collectionview_apps_list.collectionViewLayout.invalidateLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadApps()
    }

    private func setupCollectionView() {
        collectionview_apps_list.backgroundColor = .clear
        collectionview_apps_list.dataSource = self
        collectionview_apps_list.delegate = self
        collectionview_apps_list.registerClass(MyAppCell.self)

        guard let layout = collectionview_apps_list.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        layout.estimatedItemSize = .zero
        layout.minimumInteritemSpacing = rowSpacing
        layout.minimumLineSpacing = rowSpacing
        layout.sectionInset = sectionInsets
    }

    private func reloadApps() {
        apps = StreamingApp.apps(for: store.load())
        updateUI()
    }

    /// First time (no apps): placeholder only. Otherwise the grid, with an "Add more" tile last.
    private func updateUI() {
        let isEmpty = apps.isEmpty
        view_empty_placeholder.isHidden = !isEmpty
        collectionview_apps_list.isHidden = isEmpty
        collectionview_apps_list.reloadData()
    }

    private func openAddApps() {
        NavigationManager.shared.showAddApps(from: navigationController) { [weak self] saved in
            self?.apps = saved
            self?.updateUI()
        }
    }

    /// Opens the app on the connected TV. Without a connected TV it asks the user to connect first.
    private func openOnTV(_ app: StreamingApp) {
        Task {
            guard await AppServices.connection.activeDevice != nil else {
                showConnectionRequired()
                return
            }
            do {
                let tvApps = try await AppServices.connection.apps()
                guard let tvApp = AppMatcher.match(app, in: tvApps) else {
                    LoggerManager.info("\(app.name) not found on the TV", category: "Apps")
                    showSimpleAlert(title: app.name, message: "\(app.name) is not available on this TV.")
                    return
                }
                try await AppServices.connection.launch(tvApp)
                LoggerManager.success("Launched \(app.name) on the TV", category: "Apps")
            } catch let error as TVError {
                LoggerManager.warning("Launching \(app.name) failed: \(error)", category: "Apps")
                showSimpleAlert(title: app.name, message: error.userMessage)
            } catch {
                showSimpleAlert(title: app.name, message: TVError.unreachable.userMessage)
            }
        }
    }

    /// Asks the user to connect a TV. Presented from the tab bar controller so the dim covers the tab bar too.
    private func showConnectionRequired() {
        let alert = ConnectionRequiredAlertVC()
        alert.onConnect = { [weak self] in
            NavigationManager.shared.showScanning(from: self?.navigationController)
        }
        (tabBarController ?? self).present(alert, animated: true)
    }

    @IBAction func onTapped_addApps(_ sender: Any) {
        openAddApps()
    }
}

extension MyAppsVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        apps.count + 1   // the last tile is "Add more"
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(MyAppCell.self, for: indexPath)
        if indexPath.item < apps.count {
            cell.configure(with: apps[indexPath.item])
        } else {
            cell.configureAddMore()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        HapticManager.trigger(.light)
        if indexPath.item == apps.count {
            openAddApps()
        } else {
            openOnTV(apps[indexPath.item])
        }
    }

    /// Exactly 3 equal columns. `floor` keeps the row from overflowing and wrapping to 2.
    private func itemWidth(for collectionWidth: CGFloat) -> CGFloat {
        let spacing = rowSpacing * (columns - 1)
        return floor((collectionWidth - spacing) / columns)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: itemWidth(for: collectionView.bounds.width), height: MyAppCell.itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        sectionInsets
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        rowSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        rowSpacing
    }
}
