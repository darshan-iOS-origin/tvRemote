import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The TV Cast screen (Figma "Screen Cast"): cast photos, videos and music from this phone to the connected TV.
///
/// Photos and videos come from the photo picker, which runs outside the app and needs no photo-library
/// permission. Music comes from the Files picker (a copy, so no file access either). The only permission
/// involved is Local Network, because the TV fetches each file from this phone. The screen has to stay open
/// while casting, since the phone is the server: going back stops the cast and cleans up.
class CastVC: UIViewController {

    private let controller = CastController()

    private let backButton = HapticButton(frame: .zero)
    private let photoCard = CastOptionCard(title: "Cast Photo", glyph: "ic_cast_photo", layout: .vertical)
    private let videoCard = CastOptionCard(title: "Cast Video", glyph: "ic_cast_video", layout: .vertical)
    private let filesCard = CastOptionCard(title: "Choose Files from Files", glyph: "ic_cast_folder", layout: .horizontal)
    private let nowPlaying = CastNowPlayingView()

    // MARK: - Lifecycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsManager.shared.logScreen(FirebaseEvents.Screen.cast)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        buildHeader()
        buildContent()
        bindController()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Back (or any pop) ends the cast: the phone is the server, so nothing can keep playing without it.
        if isMovingFromParent {
            controller.finish()
        }
    }

    // MARK: - Layout

    private func buildHeader() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.applyBackArrowStyle()

        let title = UILabel()
        title.attributedText = NSAttributedString(string: "TV Cast", attributes: [
            .font: CommonFont.bold.font(ofSize: 18),
            .foregroundColor: CommonColor.white.color,
            .kern: 0.18
        ])
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            title.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            title.centerYAnchor.constraint(equalTo: backButton.centerYAnchor)
        ])
    }

    private func buildContent() {
        let heading = UILabel()
        heading.text = "Cast Media"
        heading.font = CommonFont.bold.font(ofSize: 18)
        heading.textColor = CommonColor.white.color

        photoCard.addTarget(self, action: #selector(onTap_photo), for: .touchUpInside)
        videoCard.addTarget(self, action: #selector(onTap_video), for: .touchUpInside)
        filesCard.addTarget(self, action: #selector(onTap_files), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [photoCard, videoCard])
        row.axis = .horizontal
        row.spacing = 15
        row.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [heading, row, filesCard, nowPlaying])
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(18, after: filesCard)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // The panel with the preview can be taller than what is left of the screen, so the content scrolls.
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 28),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        nowPlaying.onPrevious = { [weak self] in
            AnalyticsManager.shared.log(FirebaseEvents.Tap.castPrev)
            self?.controller.step(by: -1)
        }
        nowPlaying.onNext = { [weak self] in
            AnalyticsManager.shared.log(FirebaseEvents.Tap.castNext)
            self?.controller.step(by: 1)
        }
        nowPlaying.onPlayPause = { [weak self] in
            AnalyticsManager.shared.log(FirebaseEvents.Tap.castPlayPause)
            self?.controller.togglePause()
        }
        nowPlaying.onScrubbing = { [weak self] scrubbing in self?.controller.setScrubbing(scrubbing) }
        nowPlaying.onSeek = { [weak self] seconds in self?.controller.seek(to: seconds) }
        nowPlaying.onStop = { [weak self] in
            AnalyticsManager.shared.log(FirebaseEvents.Tap.castStop)
            self?.controller.stopPlaying()
        }
    }

    private func bindController() {
        controller.onState = { [weak self] state in self?.render(state) }
        controller.onPreview = { [weak self] media, image in self?.nowPlaying.render(preview: media, image: image) }
        controller.onProgress = { [weak self] progress in self?.nowPlaying.render(progress: progress) }
        controller.onLocalNetworkDenied = { [weak self] in self?.showLocalNetworkDenied() }
        controller.onNotConnected = { [weak self] in self?.showConnectionRequired() }
    }

    // MARK: - Rendering

    private func render(_ state: CastController.State) {
        nowPlaying.render(state)
        if case .failed(let message) = state, presentedViewController == nil {
            showSimpleAlert(title: "Cast", message: message, okEvent: FirebaseEvents.Tap.castAlertOK)
        }
        // One thing at a time: taps on the options are ignored while a request is running. They are not dimmed,
        // so the screen does not flash every time the next item loads.
        let enabled = !controller.isBusy
        [photoCard, videoCard, filesCard].forEach { $0.isUserInteractionEnabled = enabled }
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.castBack)
        controller.finish()
        navigationController?.popViewController(animated: true)
    }

    @objc private func onTap_photo() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.castPhoto)
        openPhotoPicker(filter: .images)
    }

    @objc private func onTap_video() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.castVideo)
        openPhotoPicker(filter: .videos)
    }

    @objc private func onTap_files() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.castFiles)
        guard !controller.isBusy, presentedViewController == nil else { return }
        // `asCopy` hands over a copy inside the app, so no file-access permission is needed.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openPhotoPicker(filter: PHPickerFilter) {
        guard !controller.isBusy, presentedViewController == nil else { return }
        // Free casts used up: go straight to the Subscription screen instead of making the user pick first.
        if ClickLimitManager.shared.isCastLimitReached {
            NavigationManager.shared.showSubscription(from: self, event: FirebaseEvents.IAPEntry.castLimit)
            return
        }
        var configuration = PHPickerConfiguration()
        configuration.filter = filter
        configuration.selectionLimit = CastController.maxPhotosAndVideos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true) { [weak self] in self?.showCastLimitToast() }
    }

    /// On the open picker: how many free casts the user has used and has left. Not shown for Premium.
    private func showCastLimitToast() {
        guard let usage = ClickLimitManager.shared.castUsage else { return }
        let left = max(0, usage.limit - usage.used)
        ToastView.show("Free limit: \(usage.used) of \(usage.limit) used · \(left) left", duration: 4)
    }

    // MARK: - Alerts

    /// Local Network is off: casting cannot work until the user turns it on in Settings.
    private func showLocalNetworkDenied() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "Local Network is off",
            message: "The TV needs to reach this phone on your Wi-Fi to play your files. Turn on Local Network for this app in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            AnalyticsManager.shared.log(FirebaseEvents.Permission.castSettingsCancel, marksPremium: false)
        })
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            AnalyticsManager.shared.log(FirebaseEvents.Permission.castSettingsOpen, marksPremium: false)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        AnalyticsManager.shared.log(FirebaseEvents.Permission.castSettingsAlert, marksPremium: false)
        present(alert, animated: true)
    }

    private func showConnectionRequired() {
        guard presentedViewController == nil else { return }
        let alert = ConnectionRequiredAlertVC()
        alert.onConnect = { [weak self] in
            NavigationManager.shared.showScanning(from: self?.navigationController)
        }
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CastVC: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        ToastView.hide()
        guard !results.isEmpty else {
            AnalyticsManager.shared.log(FirebaseEvents.Tap.castPhotoCancel)
            picker.dismiss(animated: true)
            return
        }
        // Past the free limit: nothing is cast and the Subscription screen opens, once the picker is gone.
        let count = min(results.count, CastController.maxPhotosAndVideos)
        picker.dismiss(animated: true) { [weak self] in
            guard let self,
                  ClickLimitManager.shared.allowCast(count: count, event: FirebaseEvents.IAPEntry.castLimit, from: self)
            else { return }
            self.controller.cast(results)
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension CastVC: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.controller.cast(musicAt: urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.castFilesCancel)
    }
}
