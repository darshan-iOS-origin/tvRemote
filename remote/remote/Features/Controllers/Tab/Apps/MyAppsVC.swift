import UIKit

class MyAppsVC: UIViewController {

    @IBOutlet weak var collectionview_apps_list: UICollectionView!
    @IBOutlet weak var view_empty_placeholder: UIView!

    private let store = SavedAppsStore.shared
    private var apps: [StreamingApp] = []

    private let columns: CGFloat = 3
    private let sideInset: CGFloat = 16
    private let columnSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 24

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupCollectionView()
        reloadApps()
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
        guard indexPath.item == apps.count else { return }
        HapticManager.trigger(.light)
        openAddApps()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let available = collectionView.bounds.width - sideInset * 2 - columnSpacing * (columns - 1)
        return CGSize(width: floor(available / columns), height: MyAppCell.itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 8, left: sideInset, bottom: 16, right: sideInset)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        rowSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        columnSpacing
    }
}
