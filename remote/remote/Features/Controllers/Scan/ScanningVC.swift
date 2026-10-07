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
            tableview_scanned_data.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        } else {
            devices.append(device)
            tableview_scanned_data.insertRows(at: [IndexPath(row: devices.count - 1, section: 0)], with: .fade)
        }
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
