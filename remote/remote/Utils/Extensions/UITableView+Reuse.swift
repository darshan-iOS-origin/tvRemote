import UIKit

/// A cell that can be registered and dequeued by its class name (nib name == class name == identifier).
protocol ReusableCell: UITableViewCell {
    static var reuseIdentifier: String { get }
}

extension ReusableCell {
    static var reuseIdentifier: String { String(describing: self) }
}

extension UITableView {

    /// Registers a cell designed in a xib with the same name as its class.
    func registerNib<T: ReusableCell>(_ type: T.Type) {
        register(UINib(nibName: T.reuseIdentifier, bundle: nil), forCellReuseIdentifier: T.reuseIdentifier)
    }

    func dequeue<T: ReusableCell>(_ type: T.Type, for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            return T(style: .default, reuseIdentifier: T.reuseIdentifier)
        }
        return cell
    }
}
