import UIKit

class ScanningVC: UIViewController {

    @IBOutlet weak var tableview_scanned_data: UITableView!
    @IBOutlet weak var lbl_title: UILabel!
    
    private let scanner = TVScanner()
    private var devices: [TVDevice] = []
    private let dotAnimator = DotAnimator()

    private let searchingText = "Searching for TVs"

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupTableView()
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
        NavigationManager.shared.showTabs(from: navigationController)
    }
}
