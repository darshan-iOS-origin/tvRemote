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
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20)
        ])

        nowPlaying.onPrevious = { [weak self] in self?.controller.step(by: -1) }
        nowPlaying.onNext = { [weak self] in self?.controller.step(by: 1) }
        nowPlaying.onPlayPause = { [weak self] in self?.controller.togglePause() }
        nowPlaying.onStop = { [weak self] in self?.controller.stopPlaying() }
    }

    private func bindController() {
        controller.onState = { [weak self] state in self?.render(state) }
        controller.onLocalNetworkDenied = { [weak self] in self?.showLocalNetworkDenied() }
        controller.onNotConnected = { [weak self] in self?.showConnectionRequired() }
    }

    // MARK: - Rendering

    private func render(_ state: CastController.State) {
        nowPlaying.render(state)
        if case .failed(let message) = state, presentedViewController == nil {
            showSimpleAlert(title: "Cast", message: message)
        }
        // One thing at a time: the options are off while a request is running.
        let enabled = !controller.isBusy
        [photoCard, videoCard, filesCard].forEach { $0.isEnabled = enabled }
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        controller.finish()
        navigationController?.popViewController(animated: true)
    }

    @objc private func onTap_photo() {
        openPhotoPicker(filter: .images)
    }

    @objc private func onTap_video() {
        openPhotoPicker(filter: .videos)
    }

    @objc private func onTap_files() {
        guard !controller.isBusy, presentedViewController == nil else { return }
        // `asCopy` hands over a copy inside the app, so no file-access permission is needed.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openPhotoPicker(filter: PHPickerFilter) {
        guard !controller.isBusy, presentedViewController == nil else { return }
        var configuration = PHPickerConfiguration()
        configuration.filter = filter
        configuration.selectionLimit = CastController.maxPhotosAndVideos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
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
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
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
        picker.dismiss(animated: true)
        controller.cast(results)
    }
}

// MARK: - UIDocumentPickerDelegate

extension CastVC: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.controller.cast(musicAt: urls)
    }
}
