import UIKit

class ScanningVC: UIViewController {

    @IBOutlet weak var tableview_scanned_data: UITableView!

    private let scanner = TVScanner()
    private var devices: [TVDevice] = []

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
    }

    private func setupTableView() {
        tableview_scanned_data.backgroundColor = .clear
        tableview_scanned_data.separatorStyle = .none
        // The cell xib has no fixed height of its own, so give rows the 100pt it was designed at.
        tableview_scanned_data.rowHeight = 100
        tableview_scanned_data.estimatedRowHeight = 100
        tableview_scanned_data.dataSource = self
        tableview_scanned_data.registerNib(ScanningTVCell.self)
    }

    private func startScanning() {
        scanner.start { [weak self] device in
            self?.show(device)
        }
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
