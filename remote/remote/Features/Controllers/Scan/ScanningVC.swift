import UIKit

class ScanningVC: UIViewController {

    @IBOutlet weak var tableview_scanned_data: UITableView!
    @IBOutlet weak var lbl_title: UILabel!
    
    private let scanner = TVScanner()
    private var devices: [TVDevice] = []
    private let dotAnimator = DotAnimator()
    private lazy var connector = TVConnector(presenter: self)

    private let searchingText = "Searching for TVs"

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupTableView()
        #if DEBUG
        setupEmulatorButton()
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scanner.stop()
        dotAnimator.stop(restoring: searchingText + "...", on: lbl_title)
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

    private func startScanning() {
        dotAnimator.start(on: lbl_title, baseText: searchingText)
        scanner.start(onDevice: { [weak self] device in
            self?.show(device)
        }, onFinish: { [weak self] in
            guard let self else { return }
            self.dotAnimator.stop(restoring: self.searchingText + "...", on: self.lbl_title)
        })
    }

    /// Adds a new TV, or refreshes the row when the same host is reported again.
    private func show(_ device: TVDevice) {
        if let index = devices.firstIndex(where: { $0.host == device.host }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
        LoggerManager.debug("Showing \(devices.count) TV(s) in list, main thread: \(Thread.isMainThread)", category: "Scan")
        tableview_scanned_data.reloadData()
    }
}

#if DEBUG
// MARK: - Debug: add a TV by IP (Simulator + Android TV emulator)

/// The iOS Simulator cannot discover TVs, so debug builds get a button that connects to an Android TV
/// emulator by IP. Start the emulator, forward its ports on the Mac with
/// `adb forward tcp:6466 tcp:6466` and `adb forward tcp:6467 tcp:6467`, then use 127.0.0.1.
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
            message: "For the Simulator with an Android TV emulator, forward ports 6466 and 6467 with adb and use 127.0.0.1.",
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
                    let commands = missing.map { "adb forward tcp:\($0) tcp:\($0)" }.joined(separator: "\n")
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
                    message: "Nothing answered at \(address) on ports 6466 / 6467.\n\n1. Start an Android TV / Google TV emulator.\n2. Run: adb forward tcp:6466 tcp:6466\n    and: adb forward tcp:6467 tcp:6467\n3. Try 127.0.0.1 again."
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
