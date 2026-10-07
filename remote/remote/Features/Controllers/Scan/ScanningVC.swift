import UIKit

class ScanningVC: UIViewController {

    @IBOutlet weak var tableview_scanned_data: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
    }
}
