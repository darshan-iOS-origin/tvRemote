import UIKit

class MyAppsVC: UIViewController {

    @IBOutlet weak var collectionview_apps_list: UICollectionView!
    @IBOutlet weak var view_empty_placeholder: UIView!

    private let store = SavedAppsStore.shared
    private var apps: [StreamingApp] = []

    private let columns: CGFloat = 3
    private let rowSpacing: CGFloat = 24

    /// Fixed tile width: the 80pt icon plus room for the name underneath.
    private let itemWidth: CGFloat = MyAppCell.iconSize + 20
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

    /// 3 columns of fixed width. The leftover width is split into 4 equal gaps (left edge, two
    /// between the columns, right edge), so the grid is centered with even spacing on every screen.
    private func columnGap(for width: CGFloat) -> CGFloat {
        max(floor((width - columns * itemWidth) / (columns + 1)), 8)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: itemWidth, height: MyAppCell.itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let gap = columnGap(for: collectionView.bounds.width)
        return UIEdgeInsets(top: 8, left: gap, bottom: 16, right: gap)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        rowSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        columnGap(for: collectionView.bounds.width)
    }
}
