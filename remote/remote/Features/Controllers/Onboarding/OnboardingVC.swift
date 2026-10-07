import UIKit

class OnboardingVC: UIViewController {

    @IBOutlet weak var view_pager: UIView!

    private let pages = OnboardingPage.all
    private let pagerView = PagerView()
    private var currentIndex = 0

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
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupPager()
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
        pagerView.numberOfPages = pages.count
    }

    @IBAction func onTap_continue(_ sender: Any) {
        let next = currentIndex + 1
        guard next < pages.count else { return }
        collectionView.scrollToItem(at: IndexPath(item: next, section: 0), at: .centeredHorizontally, animated: true)
    }
}

extension OnboardingVC: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OnboardingPageCell.reuseIdentifier, for: indexPath)
        (cell as? OnboardingPageCell)?.configure(with: pages[indexPath.item])
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        let index = min(max(Int(round(scrollView.contentOffset.x / width)), 0), pages.count - 1)
        guard index != currentIndex else { return }
        currentIndex = index
        pagerView.setCurrentPage(index)
    }
}
