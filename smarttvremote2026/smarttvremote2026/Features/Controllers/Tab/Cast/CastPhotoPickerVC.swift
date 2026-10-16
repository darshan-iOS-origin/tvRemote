import PhotosUI
import UIKit

/// The photo and video picker for iOS 17 and later. The system picker only reports its selection when the user
/// taps Add, so this one runs it in continuous mode: every tap is reported, and the Subscription screen opens the
/// moment the user selects one item past their free limit, instead of after Add. The extra item is deselected, so
/// closing the paywall leaves the picker with the items that fit.
///
/// The system's own Cancel and Add buttons stay. In continuous mode a press on them arrives through the same
/// delegate call as a tap on a photo, so they are told apart by what arrives: the same selection again is Add,
/// and an empty selection again is Cancel.
///
/// UNVERIFIED on a device: all of the above, and `deselectAssets`. Below iOS 17 `CastVC` uses the plain picker.
@available(iOS 17.0, *)
final class CastPhotoPickerVC: UIViewController, PHPickerViewControllerDelegate {

    /// Called with the chosen items when the user taps Add, or with nothing when they cancel. The caller dismisses.
    var onFinish: (([PHPickerResult]) -> Void)?

    private let filter: PHPickerFilter
    private var picker: PHPickerViewController?
    private var selected: [PHPickerResult] = []
    /// Until this time a repeat of the selection is the picker answering our own deselect, not an Add.
    private var ignoreRepeatsUntil = Date.distantPast

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
    }

    // MARK: - Layout

    private func buildPicker() {
        // The photo-library configuration makes the picker report each item's `assetIdentifier`, which is needed to
        // deselect one. It does not ask for photo access.
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = filter
        configuration.selectionLimit = CastController.maxPhotosAndVideos
        configuration.selection = .continuousAndOrdered
        configuration.disabledCapabilities = .search
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.picker = picker
        addChild(picker)
        picker.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker.view)
        picker.didMove(toParent: self)
        NSLayoutConstraint.activate([
            picker.view.topAnchor.constraint(equalTo: view.topAnchor),
            picker.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            picker.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - PHPickerViewControllerDelegate

    /// Called on every change of the selection, and when the user presses Add or Cancel (continuous mode).
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let ids = results.compactMap(\.assetIdentifier)
        let previousIDs = selected.compactMap(\.assetIdentifier)
        if Date() >= ignoreRepeatsUntil {
            if results.isEmpty, selected.isEmpty {
                // Nothing selected and the picker reported again: Cancel.
                AnalyticsManager.shared.log(FirebaseEvents.Tap.castPhotoCancel)
                onFinish?([])
                return
            }
            if !results.isEmpty, ids == previousIDs {
                // The same selection again: Add.
                onFinish?(results)
                return
            }
        }
        selected = results
        // Past the free limit: open the Subscription screen right now and take the extra item out.
        if let left = ClickLimitManager.shared.castRemaining, results.count > left {
            let extra = results.dropFirst(left).compactMap(\.assetIdentifier)
            if !extra.isEmpty { picker.deselectAssets(withIdentifiers: extra) }
            selected = Array(results.prefix(left))
            ignoreRepeatsUntil = Date().addingTimeInterval(0.8)
            showSubscription()
        }
    }

    private func showSubscription() {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        guard !(top is SubscriptionVC) else { return }
        NavigationManager.shared.showSubscription(from: top, event: FirebaseEvents.IAPEntry.castLimit)
    }
}
