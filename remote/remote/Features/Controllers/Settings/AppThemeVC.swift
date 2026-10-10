import UIKit

/// "App Theme": a grid of backgrounds for the Remote and Keyboard tabs, two to a row. The first is the
/// app's gradient, the rest are photos. Tapping one selects it; Apply saves it. Built in code; open it
/// with `NavigationManager.showAppTheme(from:)`.
final class AppThemeVC: UIViewController {

    private static let columns: CGFloat = 2
    /// Without Premium the first two themes (the default and one photo) are free; the rest are locked.
    private static let freeThemeCount = 2
    private static let spacing: CGFloat = 16
    private static let cellHeight: CGFloat = 200
    /// Room under the last row for the Apply button that floats over the grid.
    private static let bottomClearance: CGFloat = 100

    private let backButton = HapticButton(type: .custom)
    private let titleLabel = UILabel()
    private let applyButton = HapticButton(type: .custom)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Self.spacing
        layout.minimumLineSpacing = Self.spacing
        layout.sectionInset = UIEdgeInsets(top: 8, left: Self.spacing, bottom: Self.bottomClearance, right: Self.spacing)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.register(ThemeCell.self, forCellWithReuseIdentifier: ThemeCell.reuseIdentifier)
        return view
    }()

    private var selectedIndex = ThemeManager.selectedIndex

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        NotificationCenter.default.addObserver(self, selector: #selector(premiumChanged),
                                               name: SubscriptionManager.didChangeNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func setupViews() {
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        titleLabel.text = "App Theme"
        titleLabel.font = CommonFont.semibold.font(ofSize: 16)
        titleLabel.textColor = CommonColor.white.color

        applyButton.setTitle("Apply", for: .normal)
        applyButton.setTitleColor(CommonColor.white.color, for: .normal)
        applyButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        applyButton.backgroundColor = UIColor(hex: 0x004BF9)
        applyButton.addTarget(self, action: #selector(onTap_apply), for: .touchUpInside)

        [backButton, titleLabel, collectionView, applyButton].forEach {
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

            collectionView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            applyButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            applyButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            applyButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            applyButton.heightAnchor.constraint(equalToConstant: LottieManager.buttonHeight)
        ])
        LottieManager.applyButtonBackground(to: applyButton)
    }

    private func isLocked(index: Int) -> Bool {
        index >= Self.freeThemeCount && !SubscriptionManager.shared.isPremium
    }

    /// Bought or restored: take the locks off.
    @objc private func premiumChanged() {
        collectionView.reloadData()
    }

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    /// Saves the choice, tells the user, and goes back to Settings.
    @objc private func onTap_apply() {
        // A locked theme can be selected to look at, but only Premium can apply it.
        guard !isLocked(index: selectedIndex) else {
            HapticManager.trigger(.light)
            NavigationManager.shared.showSubscription(from: self)
            return
        }
        ThemeManager.selectedIndex = selectedIndex
        showSimpleAlert(title: "App Theme", message: "Theme applied successfully.") { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

extension AppThemeVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        ThemeManager.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThemeCell.reuseIdentifier, for: indexPath)
        (cell as? ThemeCell)?.configure(index: indexPath.item, isSelected: indexPath.item == selectedIndex,
                                        isLocked: isLocked(index: indexPath.item))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        HapticManager.trigger(.light)
        guard indexPath.item != selectedIndex else { return }
        selectedIndex = indexPath.item
        collectionView.reloadData()
    }

    /// Exactly two equal columns. `floor` keeps the pair from overflowing and wrapping to one.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let gaps = Self.spacing * (Self.columns + 1)
        let width = floor((collectionView.bounds.width - gaps) / Self.columns)
        return CGSize(width: max(width, 0), height: Self.cellHeight)
    }
}

/// One theme: the gradient (index 0) or a photo, with a blue border and a checkmark when selected.
private final class ThemeCell: UICollectionViewCell {

    static let reuseIdentifier = "ThemeCell"

    private let gradient = GradientBackgroundView()
    private let imageView = UIImageView()
    private let check = UIImageView()
    /// The lock on a theme that needs Premium: the same icon as the locked rows in History.
    private let lockIcon = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 20
        contentView.layer.borderWidth = 2
        contentView.clipsToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        check.image = IconsHelper.image(systemName: "checkmark", pointSize: 12)
        check.tintColor = CommonColor.white.color
        check.contentMode = .center
        check.backgroundColor = UIColor(hex: 0x004BF9)
        check.layer.cornerRadius = 12
        check.clipsToBounds = true

        lockIcon.image = UIImage(named: "lock") ?? UIImage(systemName: "lock.fill")
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.isHidden = true

        [gradient, imageView, check, lockIcon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        for fill in [gradient, imageView] {
            NSLayoutConstraint.activate([
                fill.topAnchor.constraint(equalTo: contentView.topAnchor),
                fill.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                fill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                fill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }
        NSLayoutConstraint.activate([
            check.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            check.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            check.widthAnchor.constraint(equalToConstant: 24),
            check.heightAnchor.constraint(equalToConstant: 24),
            // The lock takes the check's place, top right.
            lockIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            lockIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            lockIcon.widthAnchor.constraint(equalToConstant: 24),
            lockIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("ThemeCell is built in code")
    }

    func configure(index: Int, isSelected: Bool, isLocked: Bool = false) {
        let name = ThemeManager.imageName(for: index)
        imageView.image = name.flatMap { UIImage(named: $0) }
        imageView.isHidden = name == nil
        gradient.isHidden = name != nil
        // A locked theme shows only the lock (its blue border still shows it is the selected one).
        check.isHidden = !isSelected || isLocked
        lockIcon.isHidden = !isLocked
        contentView.layer.borderColor = (isSelected ? UIColor(hex: 0x004BF9) : UIColor(hex: 0x202A40)).cgColor
        accessibilityLabel = (index == 0 ? "Default theme" : "Theme \(index)") + (isLocked ? ", locked, Premium required" : "")
        accessibilityValue = isSelected ? "Selected" : "Not selected"
    }
}
