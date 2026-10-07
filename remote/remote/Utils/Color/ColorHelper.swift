import UIKit

enum CommonColor: String {
    case primaryBlue = "primary_blue"
    case secondaryGray = "secondary_gray"
    case secondaryDarkGray = "secondary_dark_gray"
    case white = "white"

    var color: UIColor {
        UIColor(named: rawValue) ?? fallback
    }

    private var fallback: UIColor {
        switch self {
        case .primaryBlue: .systemBlue
        case .secondaryGray: .systemGray
        case .secondaryDarkGray: .darkGray
        case .white: .white
        }
    }
}
