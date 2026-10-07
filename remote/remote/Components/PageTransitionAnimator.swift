import UIKit

enum SwipeDirection {
    /// Content moves to the left (next page).
    case left
    /// Content moves to the right (previous page).
    case right
}

enum PageTransitionAnimator {

    /// Slides `views` out in `direction`, runs `update` to swap their content,
    /// then slides them in from the opposite side.
    static func animate(
        direction: SwipeDirection,
        views: [UIView],
        update: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        let distance: CGFloat = (views.first?.superview?.bounds.width ?? UIScreen.main.bounds.width) * 0.4
        let outX = direction == .left ? -distance : distance

        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
            views.forEach {
                $0.transform = CGAffineTransform(translationX: outX, y: 0)
                $0.alpha = 0
            }
        } completion: { _ in
            update()
            views.forEach { $0.transform = CGAffineTransform(translationX: -outX, y: 0) }
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                views.forEach {
                    $0.transform = .identity
                    $0.alpha = 1
                }
            } completion: { _ in
                completion?()
            }
        }
    }
}
