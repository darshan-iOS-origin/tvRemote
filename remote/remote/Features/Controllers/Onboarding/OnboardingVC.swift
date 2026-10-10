import UIKit

class OnboardingVC: UIViewController {

    @IBOutlet weak var view_pager: UIView!
    @IBOutlet weak var btn_continue: UIButton!

    private let pages = OnboardingPage.all
    private let pagerView = PagerView()
    private var currentIndex = 0
    private var selectedBrand: TVBrand?
    private var selectedBrandID: String?

    /// Intro pages plus the final brand-selection page.
    private var totalPages: Int { pages.count + 1 }
    private var brandPageIndex: Int { pages.count }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.contentInsetAdjustmentBehavior = .never
        cv.dataSource = self
        cv.delegate = self
        cv.register(OnboardingPageCell.self, forCellWithReuseIdentifier: OnboardingPageCell.reuseIdentifier)
        cv.register(OnboardingBrandCell.self, forCellWithReuseIdentifier: OnboardingBrandCell.reuseIdentifier)
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupPager()
        applyGradientBackground()
        LottieManager.applyButtonBackground(to: btn_continue)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
              layout.itemSize != collectionView.bounds.size else { return }
        layout.itemSize = collectionView.bounds.size
        layout.invalidateLayout()
        collectionView.contentOffset = CGPoint(x: CGFloat(currentIndex) * collectionView.bounds.width, y: 0)
    }

    private func setupCollectionView() {
        view.insertSubview(collectionView, at: 0)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupPager() {
        pagerView.translatesAutoresizingMaskIntoConstraints = false
        view_pager.addSubview(pagerView)
        NSLayoutConstraint.activate([
            pagerView.centerXAnchor.constraint(equalTo: view_pager.centerXAnchor),
            pagerView.centerYAnchor.constraint(equalTo: view_pager.centerYAnchor),
            pagerView.widthAnchor.constraint(equalToConstant: 200),
            pagerView.heightAnchor.constraint(equalTo: view_pager.heightAnchor)
        ])
        pagerView.numberOfPages = totalPages
    }

    @IBAction func onTap_continue(_ sender: Any) {
        let next = currentIndex + 1
        guard next < totalPages else {
            // Last page: `selectedBrand` holds the user's choice. Scanning is next; the subscription
            // screens come after it, before the tabs.
            NavigationManager.shared.showScanning(from: navigationController)
            return
        }
        collectionView.scrollToItem(at: IndexPath(item: next, section: 0), at: .centeredHorizontally, animated: true)
    }
}

extension OnboardingVC: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        totalPages
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == brandPageIndex {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OnboardingBrandCell.reuseIdentifier, for: indexPath)
            if let brandCell = cell as? OnboardingBrandCell {
                brandCell.configure(selectedID: selectedBrandID)
                brandCell.onBrandSelected = { [weak self] option in
                    self?.selectedBrand = option.brand
                    self?.selectedBrandID = option.id
                }
            }
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OnboardingPageCell.reuseIdentifier, for: indexPath)
        (cell as? OnboardingPageCell)?.configure(with: pages[indexPath.item])
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        let index = min(max(Int(round(scrollView.contentOffset.x / width)), 0), totalPages - 1)
        guard index != currentIndex else { return }
        currentIndex = index
        pagerView.setCurrentPage(index)
    }
}
