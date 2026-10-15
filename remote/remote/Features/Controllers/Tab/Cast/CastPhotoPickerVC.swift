import PhotosUI
import UIKit

/// The photo and video picker for iOS 17 and later. The system picker only reports its selection when the user
/// taps Add, so this one runs it in continuous mode (every tap is reported) with the system's Add and Cancel
/// hidden and its own underneath. That lets the Subscription screen open the moment the user selects one item
/// past their free limit, instead of after Add. The extra item is deselected, so closing the paywall leaves the
/// picker with the items that fit.
///
/// UNVERIFIED on a device: that the picker reports each tap in continuous mode and that `deselectAssets` works
/// for it. Below iOS 17 `CastVC` uses the plain picker.
@available(iOS 17.0, *)
final class CastPhotoPickerVC: UIViewController, PHPickerViewControllerDelegate {

    /// Called with the chosen items when the user taps Add, or with nothing when they cancel. The caller dismisses.
    var onFinish: (([PHPickerResult]) -> Void)?

    private let filter: PHPickerFilter
    private var picker: PHPickerViewController?
    private var selected: [PHPickerResult] = []
    private let cancelButton = HapticButton(type: .custom)
    private let addButton = HapticButton(type: .custom)

    init(filter: PHPickerFilter) {
        self.filter = filter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("CastPhotoPickerVC is built in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GradientBackgroundView.baseColor
        buildPicker()
        buildBar()
        updateAddButton()
    }

    // MARK: - Layout

    private func buildPicker() {
        // The photo-library configuration makes the picker report each item's `assetIdentifier`, which is needed to
        // deselect one. It does not ask for photo access.
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = filter
        configuration.selectionLimit = CastController.maxPhotosAndVideos
        configuration.selection = .continuousAndOrdered
        configuration.disabledCapabilities = [.selectionActions, .search]
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.picker = picker
        addChild(picker)
        picker.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker.view)
        picker.didMove(toParent: self)
    }

    private func buildBar() {
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(CommonColor.white.color, for: .normal)
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)

        addButton.setTitleColor(CommonColor.white.color, for: .normal)
        addButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
        addButton.backgroundColor = CommonColor.primaryBlue.color
        addButton.addTarget(self, action: #selector(tapAdd), for: .touchUpInside)

        for button in [cancelButton, addButton] {
            button.titleLabel?.font = CommonFont.bold.font(ofSize: 16)
            button.layer.cornerRadius = 22
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }

        let bar = UIStackView(arrangedSubviews: [cancelButton, addButton])
        bar.spacing = 12
        bar.distribution = .fillEqually
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        guard let picker else { return }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            picker.view.topAnchor.constraint(equalTo: view.topAnchor),
            picker.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.view.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -8),
            bar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            bar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8)
        ])
    }

    private func updateAddButton() {
        let count = selected.count
        addButton.isEnabled = count > 0
        addButton.setTitle(count > 0 ? "Add (\(count))" : "Add", for: .normal)
    }

    // MARK: - Actions

    @objc private func tapCancel() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.castPhotoCancel)
        onFinish?([])
    }

    @objc private func tapAdd() {
        guard !selected.isEmpty else { return }
        onFinish?(selected)
    }

    // MARK: - PHPickerViewControllerDelegate

    /// Called on every change of the selection (continuous mode).
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        selected = results
        // Past the free limit: open the Subscription screen right now and take the extra item out.
        if let left = ClickLimitManager.shared.castRemaining, results.count > left {
            let extra = results.dropFirst(left).compactMap(\.assetIdentifier)
            if !extra.isEmpty { picker.deselectAssets(withIdentifiers: extra) }
            selected = Array(results.prefix(left))
            showSubscription()
        }
        updateAddButton()
    }

    private func showSubscription() {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        guard !(top is SubscriptionVC) else { return }
        NavigationManager.shared.showSubscription(from: top, event: FirebaseEvents.IAPEntry.castLimit)
    }
}
