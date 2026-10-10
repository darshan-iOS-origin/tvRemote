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

    /// Shown instead of the list when the search finds no app.
    private let emptyView = UIStackView()
    private let emptyMessageLabel = UILabel()

    /// Table bottom above the Add button. Used while the button is showing.
    private lazy var tableBottomToAddButton = tableview_apps.bottomAnchor.constraint(equalTo: btn_add.topAnchor, constant: -12)

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        selectedIDs = Set(store.load())
        btn_back.applyBackArrowStyle()
        LottieManager.applyButtonBackground(to: btn_add)
        setupTableView()
        setupEmptyView()
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

    /// "No Apps Found" with a short description, centred in the space between the search box and the keyboard
    /// (or the bottom of the screen). It does not take touches, so the search box stays usable.
    private func setupEmptyView() {
        let image = UIImageView(image: UIImage(named: "empty_apps"))
        image.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "No Apps Found"
        title.font = CommonFont.bold.font(ofSize: 20)
        title.textColor = CommonColor.white.color
        title.textAlignment = .center
        emptyMessageLabel.font = CommonFont.medium.font(ofSize: 14)
        emptyMessageLabel.textColor = CommonColor.secondaryGray.color
        emptyMessageLabel.textAlignment = .center
        emptyMessageLabel.numberOfLines = 0
        [image, title, emptyMessageLabel].forEach { emptyView.addArrangedSubview($0) }
        emptyView.axis = .vertical
        emptyView.alignment = .center
        emptyView.spacing = 12
        emptyView.setCustomSpacing(16, after: image)
        emptyView.isHidden = true
        emptyView.isUserInteractionEnabled = false
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        // The free space under the search box, down to the keyboard (or the safe area when it is closed).
        let area = UILayoutGuide()
        view.addLayoutGuide(area)
        NSLayoutConstraint.activate([
            area.topAnchor.constraint(equalTo: view_base_search.bottomAnchor),
            area.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: area.centerYAnchor),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            image.widthAnchor.constraint(equalToConstant: 140),
            image.heightAnchor.constraint(equalToConstant: 140)
        ])
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

        let isEmpty = visibleApps.isEmpty
        tableview_apps.isHidden = isEmpty
        emptyView.isHidden = !isEmpty
        emptyMessageLabel.text = "We couldn't find any app matching \"\(query)\". Check the spelling or try a different name."
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
