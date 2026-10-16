import UIKit

final class PagerView: UIView {

    private let dotHeight: CGFloat = 8
    private let inactiveWidth: CGFloat = 8
    private let activeWidth: CGFloat = 40
    private let spacing: CGFloat = 8

    private let stack = UIStackView()
    private var dots: [UIView] = []
    private var widthConstraints: [NSLayoutConstraint] = []

    private(set) var currentPage = 0

    var numberOfPages = 0 {
        didSet { rebuild() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: dotHeight)
        ])
    }

    private func rebuild() {
        dots.forEach { $0.removeFromSuperview() }
        dots.removeAll()
        widthConstraints.removeAll()

        for _ in 0..<numberOfPages {
            let dot = UIView()
            dot.layer.cornerRadius = dotHeight / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            let width = dot.widthAnchor.constraint(equalToConstant: inactiveWidth)
            width.isActive = true
            dot.heightAnchor.constraint(equalToConstant: dotHeight).isActive = true
            stack.addArrangedSubview(dot)
            dots.append(dot)
            widthConstraints.append(width)
        }
        currentPage = min(currentPage, max(numberOfPages - 1, 0))
        applyState()
    }

    func setCurrentPage(_ page: Int, animated: Bool = true) {
        guard page >= 0, page < numberOfPages else { return }
        currentPage = page
        guard animated else {
            applyState()
            return
        }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: [.beginFromCurrentState]) {
            self.applyState()
            self.layoutIfNeeded()
        }
    }

    private func applyState() {
        for (index, dot) in dots.enumerated() {
            let isActive = index == currentPage
            widthConstraints[index].constant = isActive ? activeWidth : inactiveWidth
            dot.backgroundColor = isActive ? CommonColor.primaryBlue.color : CommonColor.secondaryGray.color
        }
    }
}
