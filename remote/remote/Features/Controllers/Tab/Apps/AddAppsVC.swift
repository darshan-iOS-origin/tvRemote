import UIKit

class AddAppsVC: UIViewController {

    @IBOutlet weak var btn_back: UIButton!
    @IBOutlet weak var view_base_search: UIView!
    @IBOutlet weak var txt_search: UITextField!
    @IBOutlet weak var tableview_apps: UITableView!
    @IBOutlet weak var btn_add: UIButton!
    /// Storyboard constraint: table bottom to the safe area. Used while the Add button is hidden.
    /// Strong on purpose: a deactivated constraint is removed from its view and would be released.
    @IBOutlet var constraint_table_bottom: NSLayoutConstraint!

    /// Called with the saved apps after the user taps Add.
    var onSave: (([StreamingApp]) -> Void)?

    private let store = SavedAppsStore.shared
    private var selectedIDs: Set<String> = []
    private var visibleApps: [StreamingApp] = StreamingApp.catalog
    private var isAddButtonShown: Bool?

    /// Table bottom above the Add button. Used while the button is showing.
    private lazy var tableBottomToAddButton = tableview_apps.bottomAnchor.constraint(equalTo: btn_add.topAnchor, constant: -12)

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        selectedIDs = Set(store.load())
        btn_back.applyBackArrowStyle()
        setupTableView()
        txt_search.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        updateAddButton(animated: false)
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

    /// The Add button only shows while at least one app is selected. The table's bottom follows it:
    /// above the button when shown, down to the safe area when hidden. Exactly one is active.
    private func updateAddButton(animated: Bool) {
        let show = !selectedIDs.isEmpty
        guard show != isAddButtonShown else { return }
        isAddButtonShown = show

        if show {
            constraint_table_bottom.isActive = false
            tableBottomToAddButton.isActive = true
            btn_add.isHidden = false
        } else {
            tableBottomToAddButton.isActive = false
            constraint_table_bottom.isActive = true
        }

        let changes = {
            self.btn_add.alpha = show ? 1 : 0
            self.view.layoutIfNeeded()
        }

        guard animated else {
            changes()
            btn_add.isHidden = !show
            return
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: changes) { _ in
            // A quick select/deselect may have flipped the state again while this was running.
            if self.isAddButtonShown == false { self.btn_add.isHidden = true }
        }
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
        updateAddButton(animated: true)
    }
}
