import Lottie
import UIKit

class ScanningVC: UIViewController {

    @IBOutlet weak var tableview_scanned_data: UITableView!
    @IBOutlet weak var lbl_title: UILabel!
    /// The empty square under the description where the scanning animation plays.
    @IBOutlet weak var view_lottie_scanning: UIView!
    /// "Connect to Your TV": shown once the first TV has been found.
    @IBOutlet weak var lbl_connect: UILabel!
    
    private let scanner = TVScanner()
    private var devices: [TVDevice] = []
    private let dotAnimator = DotAnimator()
    private lazy var connector = TVConnector(presenter: self)
    private var scanningAnimation: LottieAnimationView?
    private let rescanButton = HapticButton(type: .custom)
    /// Changes with every scan (and when the screen goes away), so a scan that was cancelled or replaced
    /// cannot show an alert or touch the screen later.
    private var scanSession = 0
    /// True after the user was sent to Settings to turn on Local Network access: scan again on return.
    private var waitingForSettings = false

    /// Set once the user has refused Local Network access. The first refusal sends the user on to the
    /// tabs; after that, coming back here asks them to turn it on in Settings.
    private static let deniedBeforeKey = "scan.localNetworkDeniedBefore"

    private let searchingText = "Searching for TVs"

    /// True when opened from "+" to switch TV: shows a back button and returns to the previous screen
    /// after connecting, instead of opening the tabs.
    var isAddingTV = false
    private let backButton = HapticButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupTableView()
        lbl_connect.isHidden = true
        if isAddingTV { setupBackButton() }
        setupRescanButton()
        #if DEBUG
        setupEmulatorButton()
        #endif
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !scanner.isScanning else { return }
        beginScan()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scanSession += 1
        scanner.stop()
        dotAnimator.stop(restoring: searchingText + "...", on: lbl_title)
        stopScanningAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isAddingTV { backButton.updateGlassFallbackCorners() }
    }

    private func setupBackButton() {
        connector.onConnected = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        backButton.setImage(IconsHelper.image(systemName: "chevron.left", pointSize: 14), for: .normal)
        backButton.tintColor = CommonColor.white.color
        backButton.applyGlassStyle()
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        // The storyboard puts the title 30 pt under the safe area, which is where the button is.
        // Move it below the button: 8 pt margin + 44 pt button + 16 pt gap.
        let titleTop = view.constraints.first {
            $0.firstItem === lbl_title && $0.firstAttribute == .top && $0.secondItem === view.safeAreaLayoutGuide
        }
        titleTop?.constant = 8 + 44 + 16
    }

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    private func setupTableView() {
        tableview_scanned_data.backgroundColor = .clear
        tableview_scanned_data.separatorStyle = .none
        tableview_scanned_data.rowHeight = 100
        tableview_scanned_data.estimatedRowHeight = 100
        tableview_scanned_data.dataSource = self
        tableview_scanned_data.delegate = self
        tableview_scanned_data.registerNib(ScanningTVCell.self)
    }

    /// Loops the scanning animation for as long as the search runs.
    private func startScanningAnimation() {
        if scanningAnimation == nil {
            scanningAnimation = LottieManager.place(.scanning, in: view_lottie_scanning, loop: .loop)
        }
        view_lottie_scanning.isHidden = false
        scanningAnimation?.play()
    }

    private func stopScanningAnimation() {
        scanningAnimation?.stop()
        view_lottie_scanning.isHidden = true
    }

    /// Checks Local Network access first, then scans for 30 seconds.
    private func beginScan() {
        scanSession += 1
        let session = scanSession
        rescanButton.isHidden = true
        startScanningAnimation()
        dotAnimator.start(on: lbl_title, baseText: searchingText)

        Task { [weak self] in
            let access = await NWBrowserLocalNetworkAuthorizer().requestAuthorization()
            guard let self, session == self.scanSession else { return }
            switch access {
            case .denied:
                self.handleAccessDenied()
            case .granted:
                UserDefaults.standard.set(false, forKey: Self.deniedBeforeKey)
                self.startScanning(session: session)
            case .undetermined:
                // No answer yet: the scan itself shows the system prompt if it is still needed.
                self.startScanning(session: session)
            }
        }
    }

    private func startScanning(session: Int) {
        scanner.start(onDevice: { [weak self] device in
            guard let self, session == self.scanSession else { return }
            self.show(device)
        }, onFinish: { [weak self] in
            guard let self, session == self.scanSession else { return }
            self.scanFinished()
        })
    }

    private func stopSearchingUI() {
        dotAnimator.stop(restoring: searchingText + "...", on: lbl_title)
        stopScanningAnimation()
    }

    /// The 30 seconds are over. The Rescan button appears; with no TV found, an alert says so.
    private func scanFinished() {
        stopSearchingUI()
        rescanButton.isHidden = false
        guard devices.isEmpty else { return }

        let alert = UIAlertController(
            title: "No Device Found",
            message: "We couldn't find a TV in 30 seconds. Make sure your TV is on and connected to the same Wi-Fi network as this iPhone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Rescan", style: .default) { [weak self] _ in
            self?.rescan()
        })
        alert.addAction(UIAlertAction(title: "Okay", style: .cancel) { [weak self] _ in
            self?.openTabsWithoutTV()
        })
        present(alert, animated: true)
    }

    /// Local Network access was refused. The first time, scanning stops and the app goes on to the tabs
    /// without a TV. After that, the user is asked to turn access on in Settings.
    private func handleAccessDenied() {
        scanner.stop()
        stopSearchingUI()
        rescanButton.isHidden = false

        guard UserDefaults.standard.bool(forKey: Self.deniedBeforeKey) else {
            UserDefaults.standard.set(true, forKey: Self.deniedBeforeKey)
            openTabsWithoutTV()
            return
        }
        let alert = UIAlertController(
            title: "Local Network Access Needed",
            message: "Turn on Local Network access for this app in Settings so it can find the TVs on your Wi-Fi.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            self?.waitingForSettings = true
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    private func openTabsWithoutTV() {
        NavigationManager.shared.showTabs(from: navigationController)
    }

    /// Starts again with an empty list.
    private func rescan() {
        devices.removeAll()
        lbl_connect.isHidden = true
        tableview_scanned_data.reloadData()
        beginScan()
    }

    @objc private func onTap_rescan() {
        scanner.stop()
        rescan()
    }

    /// Back from Settings: try again, in case access was turned on.
    @objc private func appEnteredForeground() {
        guard waitingForSettings, viewIfLoaded?.window != nil else { return }
        waitingForSettings = false
        rescan()
    }

    /// "Rescan": a small pill at the bottom centre, shown when a scan has ended.
    private func setupRescanButton() {
        rescanButton.setTitle("Rescan", for: .normal)
        rescanButton.setTitleColor(CommonColor.white.color, for: .normal)
        rescanButton.titleLabel?.font = CommonFont.semibold.font(ofSize: 14)
        rescanButton.backgroundColor = UIColor(hex: 0x202A40)
        rescanButton.layer.cornerRadius = 16
        rescanButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        rescanButton.addTarget(self, action: #selector(onTap_rescan), for: .touchUpInside)
        rescanButton.isHidden = true
        rescanButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rescanButton)
        NSLayoutConstraint.activate([
            rescanButton.heightAnchor.constraint(equalToConstant: 32),
            rescanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rescanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    /// Adds a new TV, or refreshes the row when the same host is reported again.
    private func show(_ device: TVDevice) {
        if let index = devices.firstIndex(where: { $0.host == device.host }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
        LoggerManager.debug("Showing \(devices.count) TV(s) in list, main thread: \(Thread.isMainThread)", category: "Scan")
        lbl_connect.isHidden = false
        tableview_scanned_data.reloadData()
    }
}

#if DEBUG
// MARK: - Debug: add a TV by IP (Simulator + Android TV emulator)

/// The iOS Simulator cannot discover TVs, so debug builds get a button that connects to an Android TV
/// emulator by IP. Start the emulator, redirect its ports to the Mac with
/// `adb emu redir add tcp:6466:6466` and `adb emu redir add tcp:6467:6467`, then use 127.0.0.1.
/// Use `emu redir`, not `adb forward`: with `adb forward` pairing works but the TV closes the control
/// connection (TLS error -9816).
/// Release builds do not contain any of this.
extension ScanningVC {

    private static let lastIPKey = "debug.lastManualTVAddress"
    private static let emulatorButtonTag = 0xE_01

    fileprivate func setupEmulatorButton() {
        let button = HapticButton(type: .custom)
        button.tag = Self.emulatorButtonTag
        button.setTitle("Add TV by IP", for: .normal)
        button.setTitleColor(CommonColor.white.color, for: .normal)
        button.titleLabel?.font = CommonFont.semibold.font(ofSize: 14)
        button.backgroundColor = CommonColor.primaryBlue.color
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        button.addTarget(self, action: #selector(onTap_addByIP), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 32),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            button.centerYAnchor.constraint(equalTo: lbl_title.centerYAnchor)
        ])
    }

    @objc fileprivate func onTap_addByIP() {
        let alert = UIAlertController(
            title: "Add TV by IP",
            message: "For the Simulator with an Android TV emulator, redirect ports 6466 and 6467 with adb emu redir add and use 127.0.0.1.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "127.0.0.1"
            field.text = UserDefaults.standard.string(forKey: Self.lastIPKey) ?? "127.0.0.1"
            field.keyboardType = .numbersAndPunctuation
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Connect", style: .default) { [weak self, weak alert] _ in
            let address = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            self?.connectToManualTV(at: address)
        })
        present(alert, animated: true)
    }

    private func connectToManualTV(at address: String) {
        guard !address.isEmpty else { return }
        UserDefaults.standard.set(address, forKey: Self.lastIPKey)

        let button = view.viewWithTag(Self.emulatorButtonTag) as? UIButton
        button?.isEnabled = false
        button?.setTitle("Checking…", for: .normal)

        Task {
            defer {
                button?.isEnabled = true
                button?.setTitle("Add TV by IP", for: .normal)
            }
            do {
                let device = try await ManualTVProbe().androidTV(at: address)
                LoggerManager.info("Manual TV found at \(address): \(device.summaryLine), open ports \(device.openControlPorts.sorted())", category: "Scan")
                let missing = [ManualTVProbe.androidPairingPort, ManualTVProbe.androidControlPort]
                    .filter { !device.openControlPorts.contains($0) }
                guard missing.isEmpty else {
                    let list = missing.map(String.init).joined(separator: ", ")
                    let commands = missing.map { "adb emu redir add tcp:\($0):\($0)" }.joined(separator: "\n")
                    showSimpleAlert(
                        title: "Port \(list) not reachable",
                        message: "Pairing needs both 6467 and 6466. Run:\n\(commands)\nthen try again."
                    )
                    return
                }
                show(device)
                connector.connect(to: device)
            } catch ManualTVProbe.Failure.notLocalAddress {
                showSimpleAlert(
                    title: "Not a local address",
                    message: "Use a private IP such as 192.168.x.x or 10.x.x.x. For the Simulator with an Android TV emulator use 127.0.0.1."
                )
            } catch {
                showSimpleAlert(
                    title: "No TV answered",
                    message: "Nothing answered at \(address) on ports 6466 / 6467.\n\n1. Start an Android TV / Google TV emulator.\n2. Run: adb emu redir add tcp:6466:6466\n    and: adb emu redir add tcp:6467:6467\n3. Try 127.0.0.1 again."
                )
            }
        }
    }
}
#endif

extension ScanningVC: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(ScanningTVCell.self, for: indexPath)
        cell.configure(with: devices[indexPath.row])
        return cell
    }
}

extension ScanningVC: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard devices.indices.contains(indexPath.row) else { return }
        let device = devices[indexPath.row]
        LoggerManager.info("Selected TV: \(device.name) (\(device.host))", category: "Scan")
        connector.connect(to: device)
    }
}
