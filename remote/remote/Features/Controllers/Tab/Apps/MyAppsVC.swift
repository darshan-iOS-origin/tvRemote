import UIKit

class MyAppsVC: UIViewController {

    
    @IBOutlet weak var collectionview_apps_list: UICollectionView!
    @IBOutlet weak var view_empty_placeholder: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()

    }

    @IBAction func onTapped_addApps(_ sender: Any) {
        
    }
}
