import UIKit

class ScanningTVCell: UITableViewCell, ReusableCell {

    @IBOutlet weak var view_bg: UIView!
    @IBOutlet weak var lbl_title: UILabel!
    @IBOutlet weak var lbl_description: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        selectionStyle = .none
        view_bg.layer.cornerRadius = 20
        view_bg.layer.borderWidth = 1.5
        view_bg.layer.borderColor = UIColor(hex: 0x202A40).cgColor
        view_bg.clipsToBounds = true
    }

    /// Title is the TV's name; the description reads like "Android TV. 192.168.1.11".
    func configure(with device: TVDevice) {
        lbl_title.text = device.name
        lbl_description.text = "\(device.platform.displayName). \(device.host)"
    }
}
