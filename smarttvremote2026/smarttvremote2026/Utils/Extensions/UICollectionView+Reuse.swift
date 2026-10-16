import UIKit

protocol ReusableCollectionCell: UICollectionViewCell {
    static var reuseIdentifier: String { get }
}

extension ReusableCollectionCell {
    static var reuseIdentifier: String { String(describing: self) }
}

extension UICollectionView {

    /// Registers a cell that is built in code (no xib).
    func registerClass<T: ReusableCollectionCell>(_ type: T.Type) {
        register(T.self, forCellWithReuseIdentifier: T.reuseIdentifier)
    }

    func dequeue<T: ReusableCollectionCell>(_ type: T.Type, for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withReuseIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            return T(frame: .zero)
        }
        return cell
    }
}
