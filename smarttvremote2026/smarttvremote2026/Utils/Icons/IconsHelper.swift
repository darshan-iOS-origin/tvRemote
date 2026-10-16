import UIKit

enum IconsHelper {
    static func image(systemName: String, pointSize: CGFloat = 22) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize)
        return UIImage(systemName: systemName, withConfiguration: configuration)
    }
}
