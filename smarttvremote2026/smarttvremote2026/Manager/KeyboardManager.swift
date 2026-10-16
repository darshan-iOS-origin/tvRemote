import UIKit

public final class KeyboardManager: NSObject {
    
    public static let shared = KeyboardManager()
    private override init() {
        super.init()
    }
    
    public private(set) static var keyboardFrame: CGRect = .zero
    
    public static var keyboardHeight: CGFloat {
        keyboardFrame.height
    }
    
    public static var isVisible: Bool {
        keyboardFrame.height > 0
    }
    
    public private(set) static var animationDuration: TimeInterval = 0.25
    public private(set) static var animationCurve: UIView.AnimationOptions = .curveEaseOut
    public static var onWillShow: ((CGRect, TimeInterval) -> Void)?
    public static var onWillHide: ((TimeInterval) -> Void)?
    public static var onFrameChange: ((CGRect) -> Void)?
    private static var isObserving = false
    private static var observers: [NSObjectProtocol] = []
    private static var dismissTapGesture: UITapGestureRecognizer?
    
    
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    
    public static func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        
        observers = [
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { handleShow($0) },
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { handleHide($0) },
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardDidChangeFrameNotification,
                object: nil,
                queue: .main
            ) { handleFrameChange($0) }
        ]
    }
    
    public static func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }
    
    
    private static func handleShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        
        keyboardFrame = frame
        animationDuration = duration
        animationCurve = UIView.AnimationOptions(rawValue: curve)
        
        enableOutsideTapDismiss()
        
        onWillShow?(frame, duration)
        onFrameChange?(frame)
    }
    
    private static func handleHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        keyboardFrame = .zero
        disableOutsideTapDismiss()
        
        onWillHide?(duration)
        onFrameChange?(.zero)
    }
    
    private static func handleFrameChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        keyboardFrame = frame
        onFrameChange?(frame)
    }
    
    
    public static func adjustScrollView(
        _ scrollView: UIScrollView,
        for keyboardFrame: CGRect,
        in view: UIView
    ) {
        let converted = view.convert(keyboardFrame, from: nil)
        let overlap = view.bounds.intersection(converted).height
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    public static func resetScrollView(_ scrollView: UIScrollView) {
        scrollView.contentInset = .zero
        scrollView.verticalScrollIndicatorInsets = .zero
    }

    public static func scrollToVisible(
        _ targetView: UIView,
        in scrollView: UIScrollView,
        padding: CGFloat = 16,
        animated: Bool = true
    ) {
        let targetFrame = scrollView.convert(targetView.bounds, from: targetView)
        let visibleFrame = targetFrame.insetBy(dx: 0, dy: -padding)
        scrollView.scrollRectToVisible(visibleFrame, animated: animated)
    }
    
    
    private static func enableOutsideTapDismiss() {
        guard dismissTapGesture == nil,
              let window = keyWindow else { return }
        
        let tap = UITapGestureRecognizer(
            target: shared,
            action: #selector(handleOutsideTap)
        )
        tap.cancelsTouchesInView = false
        tap.delegate = shared
        window.addGestureRecognizer(tap)
        
        dismissTapGesture = tap
    }
    
    private static func disableOutsideTapDismiss() {
        guard let tap = dismissTapGesture,
              let window = keyWindow else { return }
        
        window.removeGestureRecognizer(tap)
        dismissTapGesture = nil
    }
    
    @objc private func handleOutsideTap() {
        KeyboardManager.keyWindow?.endEditing(true)
    }
}


extension KeyboardManager: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let v = view {
            if v is UITextView || v is UITextField { return false }
            if v is UIControl { return false }
            view = v.superview
        }
        return true
    }
}
