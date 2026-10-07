import UIKit

class AddAppsVC: UIViewController {

    @IBOutlet weak var btn_back: UIButton!
    @IBOutlet weak var view_base_search: UIView!
    @IBOutlet weak var txt_search: UITextField!
    @IBOutlet weak var tableview_apps: UITableView!

    /// Called with the saved apps after the user taps Add.
    var onSave: (([StreamingApp]) -> Void)?

    private let store = SavedAppsStore.shared
    private var selectedIDs: Set<String> = []
    private var visibleApps: [StreamingApp] = StreamingApp.catalog

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        selectedIDs = Set(store.load())
        btn_back.applyGlassStyle()
        setupTableView()
        txt_search.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        btn_back.updateGlassFallbackCorners()
    }

    private func setupTableView() {
        tableview_apps.backgroundColor = .clear
        tableview_apps.separatorStyle = .none
        tableview_apps.rowHeight = AppSelectCell.rowHeight
        tableview_apps.dataSource = self
        tableview_apps.delegate = self
        tableview_apps.registerClass(AppSelectCell.self)
    }

    @objc private func searchChanged() {
        let query = (txt_search.text ?? "").trimmingCharacters(in: .whitespaces)
        visibleApps = query.isEmpty
            ? StreamingApp.catalog
            : StreamingApp.catalog.filter { $0.name.localizedCaseInsensitiveContains(query) }
        tableview_apps.reloadData()
    }

    @IBAction func onTap_add(_ sender: Any) {
        let ids = StreamingApp.catalog.map(\.id).filter { selectedIDs.contains($0) }
        store.save(ids)
        LoggerManager.info("Saved apps: \(ids)", category: "Apps")
        onSave?(StreamingApp.apps(for: ids))
        navigationController?.popViewController(animated: true)
    }

    @IBAction func onTapped_back(_ sender: Any) {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension AddAppsVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleApps.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let app = visibleApps[indexPath.row]
        let cell = tableView.dequeue(AppSelectCell.self, for: indexPath)
        cell.configure(with: app, isSelected: selectedIDs.contains(app.id))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let app = visibleApps[indexPath.row]
        if selectedIDs.contains(app.id) {
            selectedIDs.remove(app.id)
        } else {
            selectedIDs.insert(app.id)
        }
        HapticManager.trigger(.light)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}
