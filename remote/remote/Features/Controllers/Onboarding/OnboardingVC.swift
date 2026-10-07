import UIKit

class OnboardingVC: UIViewController {

    @IBOutlet weak var img_bg: UIImageView!
    @IBOutlet weak var img_icon: UIImageView!
    @IBOutlet weak var lbl_title: UILabel!
    @IBOutlet weak var lbl_description: UILabel!
    @IBOutlet weak var view_pager: UIView!

    private let pages = OnboardingPage.all
    private let pagerView = PagerView()
    private var currentIndex = 0
    private var isAnimating = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPager()
        setupGestures()
        apply(pages[currentIndex])
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

    private func setupGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        left.direction = .left
        let right = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        right.direction = .right
        view.addGestureRecognizer(left)
        view.addGestureRecognizer(right)
    }

    private func apply(_ page: OnboardingPage) {
        img_bg.image = UIImage(named: page.background)
        img_icon.image = UIImage(named: page.icon)
        lbl_title.text = page.title
        lbl_description.text = page.description
    }

    private func go(to index: Int, direction: SwipeDirection) {
        guard !isAnimating, index >= 0, index < pages.count, index != currentIndex else { return }
        isAnimating = true
        currentIndex = index
        pagerView.setCurrentPage(index)
        PageTransitionAnimator.animate(
            direction: direction,
            views: [img_bg, img_icon, lbl_title, lbl_description],
            update: { [weak self] in
                guard let self else { return }
                self.apply(self.pages[index])
            },
            completion: { [weak self] in
                self?.isAnimating = false
            }
        )
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .left: go(to: currentIndex + 1, direction: .left)
        case .right: go(to: currentIndex - 1, direction: .right)
        default: break
        }
    }

    @IBAction func onTap_continue(_ sender: Any) {
        go(to: currentIndex + 1, direction: .left)
    }
}
