import UIKit

final class ElementsConfig {
    
    static let shared = ElementsConfig()
    private init() {}
    
    
    func applyONLYradius(
        to views: [UIView],
        radius: CGFloat
    ) {
        for view in views {
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = true
        }
    }
    
    func applyONLYradiusWithBGconfig(
        to views: [UIView],
        radius: CGFloat,
        bg: UIColor,
        borderColor: UIColor,
        borderWidth: CGFloat
    ) {
        for view in views {
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = true
            view.layer.backgroundColor = bg.cgColor
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = borderWidth
        }
    }
    
    func applyONLYradiusWithBGconfig(
        to viewBorderColorPairs: [(UIView, UIColor)],
        radius: CGFloat,
        bg: UIColor,
        borderWidth: CGFloat
    ) {
        for (view, borderColor) in viewBorderColorPairs {
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = true
            view.layer.backgroundColor = bg.cgColor
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = borderWidth
        }
    }
    
    func applyONLYradiuswithBorderColor(
        to: UIView,
        radius: CGFloat,
        borderWidth: CGFloat,
        borderColor: UIColor
    ) {
        to.layer.cornerRadius = radius
        to.layer.masksToBounds = true
        to.layer.borderColor = borderColor.cgColor
        to.layer.borderWidth = borderWidth
    }
    
    func applyRadius(
        to view: UIView,
        radius: CGFloat,
        topLeft: Bool = false,
        topRight: Bool = false,
        bottomLeft: Bool = false,
        bottomRight: Bool = false
    ) {
        
        var corners: UIRectCorner = []
        
        if topLeft { corners.insert(.topLeft) }
        if topRight { corners.insert(.topRight) }
        if bottomLeft { corners.insert(.bottomLeft) }
        if bottomRight { corners.insert(.bottomRight) }
        
        let path = UIBezierPath(
            roundedRect: view.bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask
    }
    
    
    func applyGradient(
        to view: UIView,
        colors: [UIColor],
        startPoint: CGPoint = CGPoint(x: 0, y: 0),
        endPoint: CGPoint = CGPoint(x: 1, y: 1),
        locations: [NSNumber]? = nil,
        cornerRadius: CGFloat = 0
    ) {
        view.layoutIfNeeded()
        
        view.layer.sublayers?
            .filter { $0.name == "GradientLayer" }
            .forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "GradientLayer"
        gradientLayer.frame = view.bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.locations = locations
        gradientLayer.cornerRadius = cornerRadius
        
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        if cornerRadius > 0 {
            view.layer.cornerRadius = cornerRadius
            view.clipsToBounds = true
        }
    }

    private static let fadeSeparatorGradientLayerName = "FadeSeparatorGradientLayer"
    private static let fadeSeparatorColor = UIColor(
        red: 117 / 255.0,
        green: 125 / 255.0,
        blue: 146 / 255.0,
        alpha: 1.0
    )

    func applyFadeSeparatorStyle(to view: UIView) {
        view.layoutIfNeeded()
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }

        view.backgroundColor = .clear

        let gradientLayer: CAGradientLayer
        if let existing = view.layer.sublayers?.first(where: {
            $0.name == Self.fadeSeparatorGradientLayerName
        }) as? CAGradientLayer {
            gradientLayer = existing
        } else {
            let layer = CAGradientLayer()
            layer.name = Self.fadeSeparatorGradientLayerName
            layer.startPoint = CGPoint(x: 0, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 0.5)
            layer.colors = [
                Self.fadeSeparatorColor.withAlphaComponent(0).cgColor,
                Self.fadeSeparatorColor.cgColor,
                Self.fadeSeparatorColor.withAlphaComponent(0).cgColor,
            ]
            layer.locations = [0, 0.5, 1]
            view.layer.insertSublayer(layer, at: 0)
            gradientLayer = layer
        }

        gradientLayer.frame = view.bounds
    }

    func updateFadeSeparatorStyle(for view: UIView) {
        view.layoutIfNeeded()
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }

        if let gradientLayer = view.layer.sublayers?.first(where: {
            $0.name == Self.fadeSeparatorGradientLayerName
        }) as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        } else {
            applyFadeSeparatorStyle(to: view)
        }
    }
    
    
    func applyRadius(
        to views: [UIView],
        radius: CGFloat,
        borderColor: UIColor = .clear,
        borderWidth: CGFloat = 0,
        shadowColor: UIColor? = nil,
        shadowOpacity: Float? = nil,
        shadowOffset: CGSize? = nil,
        shadowRadius: CGFloat? = nil
    ) {
        for view in views {
            view.layoutIfNeeded()
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = false
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = borderWidth
            
            if let shadowColor {
                view.layer.shadowColor = shadowColor.cgColor
            }
            if let shadowOpacity {
                view.layer.shadowOpacity = shadowOpacity
            }
            if let shadowOffset {
                view.layer.shadowOffset = shadowOffset
            }
            if let shadowRadius {
                view.layer.shadowRadius = shadowRadius
            }
        }
    }
    
    func applyRadiusWithGradient(
        to view: UIView,
        gradientColors: [UIColor],
        isRadius: Bool = true
    ) {
        view.layoutIfNeeded()
        
        view.layer.sublayers?
            .filter { $0.name == "LinearGradientLayer" }
            .forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "LinearGradientLayer"
        gradientLayer.frame = view.bounds
        gradientLayer.colors = gradientColors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        if isRadius {
            let radius = view.bounds.height / 2
            let maskLayer = CAShapeLayer()
            maskLayer.path = UIBezierPath(
                roundedRect: view.bounds,
                cornerRadius: radius
            ).cgPath
            gradientLayer.mask = maskLayer
        }
        
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func applyGradientWithBorderConfig(
        to views: [UIView],
        gradientColors: [UIColor],
        radius: CGFloat,
        borderColor: UIColor,
        borderWidth: CGFloat,
        startPoint: CGPoint = CGPoint(x: 0.5, y: 0),
        endPoint: CGPoint = CGPoint(x: 0.5, y: 1),
        locations: [NSNumber]? = nil
    ) {
        views.forEach { view in
            
            view.layoutIfNeeded()
            
            view.layer.sublayers?
                .filter { $0.name == "GradientLayer" }
                .forEach { $0.removeFromSuperlayer() }
            
            let gradientLayer = CAGradientLayer()
            gradientLayer.name = "GradientLayer"
            gradientLayer.frame = view.bounds
            gradientLayer.colors = gradientColors.map { $0.cgColor }
            gradientLayer.startPoint = startPoint
            gradientLayer.endPoint = endPoint
            gradientLayer.locations = locations
            gradientLayer.cornerRadius = radius
            
            view.layer.insertSublayer(gradientLayer, at: 0)
            
            view.layer.cornerRadius = radius
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = borderWidth
            view.clipsToBounds = true
        }
    }
    
    func applyUnderline(to button: UIButton, color: UIColor) {
        guard let title = button.currentTitle else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: color,
            .foregroundColor: button.titleColor(for: .normal) ?? color,
            .font: button.titleLabel?.font ?? UIFont.systemFont(ofSize: 15)
        ]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attributes), for: .normal)
    }
    
    func applySigmaShadow(
        to view: UIView,
        x: CGFloat,
        y: CGFloat,
        blur: CGFloat,
        color: UIColor,
        opacity: CGFloat
    ) {
        ThreadManager.onMain {
            view.layer.shadowColor = color.withAlphaComponent(opacity).cgColor
            view.layer.shadowOffset = CGSize(width: x, height: y)
            view.layer.shadowRadius = blur / 2   // Sigma/Figma → iOS conversion
            view.layer.shadowOpacity = 1.0
            view.layer.masksToBounds = false
        }
    }

    func clearSigmaShadow(for view: UIView) {
        ThreadManager.onMain {
            view.layer.shadowOpacity = 0
            view.layer.shadowPath = nil
        }
    }

    func updateSigmaShadowPath(
        for view: UIView,
        bounds: CGRect,
        cornerRadius: CGFloat
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        ThreadManager.onBackground {
            let path = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: cornerRadius
            ).cgPath
            ThreadManager.onMain {
                view.layer.shadowPath = path
            }
        }
    }
    
    func removeGradient(from view: UIView) {
        view.layer.sublayers?
            .filter { $0.name == "LinearGradientLayer" || $0.name == "GradientLayer" }
            .forEach { $0.removeFromSuperlayer() }
        view.backgroundColor = .clear
    }

    func applyGradientBorder(
        to view: UIView,
        colors: [UIColor],
        lineWidth: CGFloat = 1,
        cornerRadius: CGFloat = 16,
        startPoint: CGPoint = CGPoint(x: 0, y: 0),
        endPoint: CGPoint = CGPoint(x: 1, y: 1)
    ) {
        view.layoutIfNeeded()

        view.layer.sublayers?
            .filter { $0.name == "GradientBorderLayer" }
            .forEach { $0.removeFromSuperlayer() }

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "GradientBorderLayer"
        gradientLayer.frame = view.bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint

        let borderMask = CAShapeLayer()
        let inset = lineWidth / 2
        borderMask.path = UIBezierPath(
            roundedRect: view.bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: cornerRadius
        ).cgPath
        borderMask.fillColor = UIColor.clear.cgColor
        borderMask.strokeColor = UIColor.black.cgColor
        borderMask.lineWidth = lineWidth
        gradientLayer.mask = borderMask

        view.layer.cornerRadius = cornerRadius
        view.layer.masksToBounds = true
        view.layer.addSublayer(gradientLayer)
    }

    // MARK: - Primary action / capsule styling

    func applyCapsuleRadius(to view: UIView) {
        view.layoutIfNeeded()
        let radius = view.bounds.height / 2
        view.layer.cornerRadius = radius
        view.clipsToBounds = true
    }

    func applyDropShadows(
        to view: UIView,
        shadows: [ElementShadow],
        cornerRadius: CGFloat
    ) {
        guard let superview = view.superview else { return }
        superview.layoutIfNeeded()
        removeShadowHosts(for: view)

        let targetFrame = view.frame
        for (index, shadow) in shadows.enumerated() {
            let host = UIView(frame: targetFrame)
            host.isUserInteractionEnabled = false
            host.backgroundColor = .clear
            host.accessibilityIdentifier = shadowHostIdentifier(for: view, index: index)

            superview.insertSubview(host, belowSubview: view)
            configureDropShadowHost(host, shadow: shadow, frame: targetFrame, cornerRadius: cornerRadius)
        }
    }

    func applyInnerShadow(
        to view: UIView,
        shadow: ElementShadow,
        cornerRadius: CGFloat,
        force: Bool = false
    ) {
        if !force,
           let existing = view.layer.sublayers?.first(where: { $0.name == innerShadowLayerName }),
           existing.frame == view.bounds,
           abs(existing.cornerRadius - cornerRadius) < 0.5 {
            return
        }

        view.layer.sublayers?
            .filter { $0.name == innerShadowLayerName }
            .forEach { $0.removeFromSuperlayer() }

        guard view.bounds.width > 0, view.bounds.height > 0 else { return }

        let container = CALayer()
        container.name = innerShadowLayerName
        container.frame = view.bounds
        container.masksToBounds = true
        container.cornerRadius = cornerRadius

        let innerLayer = CALayer()
        innerLayer.frame = view.bounds
        innerLayer.shadowColor = shadow.color.cgColor
        innerLayer.shadowOffset = CGSize(width: shadow.x, height: shadow.y)
        innerLayer.shadowOpacity = Float(shadow.opacity)
        innerLayer.shadowRadius = shadow.blur / 2
        innerLayer.cornerRadius = cornerRadius

        let outerRect = view.bounds.insetBy(dx: -shadow.blur * 2, dy: -shadow.blur * 2)
        let outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: cornerRadius + shadow.blur)
        let cutout = UIBezierPath(roundedRect: view.bounds, cornerRadius: cornerRadius).reversing()
        outerPath.append(cutout)
        innerLayer.shadowPath = outerPath.cgPath

        container.addSublayer(innerLayer)
        view.layer.addSublayer(container)
    }

    func applyPrimaryActionStyle(
        to view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let resolvedCornerRadius = cornerRadius ?? (view.bounds.height / 2)
        let fillColor = Colors.shared.primary.resolvedColor(with: traits)
        let dropShadows = ElementShadowPresets.primaryButtonDropShadows(traitCollection: traits)

        view.backgroundColor = fillColor
        if let cornerRadius {
            view.layer.cornerRadius = cornerRadius
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
        } else {
            applyCapsuleRadius(to: view)
        }
        applyDropShadows(
            to: view,
            shadows: dropShadows,
            cornerRadius: resolvedCornerRadius
        )
        applyInnerShadow(
            to: view,
            shadow: ElementShadowPresets.primaryButtonInnerShadow,
            cornerRadius: resolvedCornerRadius,
            force: true
        )
    }

    func updatePrimaryActionStyle(
        for view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let resolvedCornerRadius = cornerRadius ?? (view.bounds.height / 2)
        let fillColor = Colors.shared.primary.resolvedColor(with: traits)
        let dropShadows = ElementShadowPresets.primaryButtonDropShadows(traitCollection: traits)

        view.backgroundColor = fillColor
        if let cornerRadius {
            view.layer.cornerRadius = cornerRadius
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
        } else {
            applyCapsuleRadius(to: view)
        }

        let hosts = shadowHosts(for: view)
        if hosts.count == dropShadows.count {
            for (host, shadow) in zip(hosts, dropShadows) {
                configureDropShadowHost(
                    host,
                    shadow: shadow,
                    frame: view.frame,
                    cornerRadius: resolvedCornerRadius
                )
            }
        } else {
            applyDropShadows(
                to: view,
                shadows: dropShadows,
                cornerRadius: resolvedCornerRadius
            )
        }

        applyInnerShadow(
            to: view,
            shadow: ElementShadowPresets.primaryButtonInnerShadow,
            cornerRadius: resolvedCornerRadius
        )
    }

    func applyPrimaryActionShadowStyle(
        to view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let resolvedCornerRadius = cornerRadius ?? (view.bounds.height / 2)
        let dropShadows = ElementShadowPresets.primaryButtonDropShadows(traitCollection: traits)

        view.backgroundColor = .clear
        view.layer.cornerRadius = resolvedCornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = false

        applyDropShadows(
            to: view,
            shadows: dropShadows,
            cornerRadius: resolvedCornerRadius
        )
    }

    func updatePrimaryActionShadowStyle(
        for view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let resolvedCornerRadius = cornerRadius ?? (view.bounds.height / 2)
        let dropShadows = ElementShadowPresets.primaryButtonDropShadows(traitCollection: traits)

        view.backgroundColor = .clear
        view.layer.cornerRadius = resolvedCornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = false

        let hosts = shadowHosts(for: view)
        if hosts.count == dropShadows.count {
            for (host, shadow) in zip(hosts, dropShadows) {
                configureDropShadowHost(
                    host,
                    shadow: shadow,
                    frame: view.frame,
                    cornerRadius: resolvedCornerRadius
                )
            }
        } else {
            applyDropShadows(
                to: view,
                shadows: dropShadows,
                cornerRadius: resolvedCornerRadius
            )
        }
    }

    func applyAddAccountOptionCardStyle(
        to view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat = 24
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let dropShadow = ElementShadowPresets.addAccountOptionCardDropShadow(traitCollection: traits)

        view.backgroundColor = Colors.shared.card.resolvedColor(with: traits)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        applyDropShadows(
            to: view,
            shadows: [dropShadow],
            cornerRadius: cornerRadius
        )
    }

    func applySearchBarStyle(
        to view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat = 12
    ) {
        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        view.backgroundColor = Colors.shared.searchBackground.resolvedColor(with: traits)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
    }

    func updateAddAccountOptionCardStyle(
        for view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat = 24
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let dropShadow = ElementShadowPresets.addAccountOptionCardDropShadow(traitCollection: traits)

        view.backgroundColor = Colors.shared.card.resolvedColor(with: traits)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        let hosts = shadowHosts(for: view)
        if hosts.count == 1 {
            configureDropShadowHost(
                hosts[0],
                shadow: dropShadow,
                frame: view.frame,
                cornerRadius: cornerRadius
            )
        } else {
            applyDropShadows(
                to: view,
                shadows: [dropShadow],
                cornerRadius: cornerRadius
            )
        }
    }

    func applyPasscodeKeyStyle(
        to view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat = 20
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let dropShadow = ElementShadowPresets.passcodeKeyDropShadow(traitCollection: traits)

        view.backgroundColor = Colors.shared.card.resolvedColor(with: traits)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        applyDropShadows(
            to: view,
            shadows: [dropShadow],
            cornerRadius: cornerRadius
        )
    }

    func updatePasscodeKeyStyle(
        for view: UIView,
        traitCollection: UITraitCollection? = nil,
        cornerRadius: CGFloat = 20
    ) {
        view.layoutIfNeeded()
        view.superview?.layoutIfNeeded()
        guard view.bounds.height > 0 else { return }

        let traits = resolvedTraitCollection(for: view, traitCollection: traitCollection)
        let dropShadow = ElementShadowPresets.passcodeKeyDropShadow(traitCollection: traits)

        view.backgroundColor = Colors.shared.card.resolvedColor(with: traits)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        let hosts = shadowHosts(for: view)
        if hosts.count == 1 {
            configureDropShadowHost(
                hosts[0],
                shadow: dropShadow,
                frame: view.frame,
                cornerRadius: cornerRadius
            )
        } else {
            applyDropShadows(
                to: view,
                shadows: [dropShadow],
                cornerRadius: cornerRadius
            )
        }
    }

    func setPasscodeKeyShadowVisibility(for view: UIView, hidden: Bool) {
        shadowHosts(for: view).forEach {
            $0.isHidden = hidden
            $0.alpha = hidden ? 0 : 1
        }
    }

    func setPasscodeKeyShadowAlpha(for view: UIView, alpha: CGFloat) {
        shadowHosts(for: view).forEach { $0.alpha = alpha }
    }

    private let innerShadowLayerName = "InnerShadowLayer"

    private func resolvedTraitCollection(
        for view: UIView,
        traitCollection: UITraitCollection?
    ) -> UITraitCollection {
        traitCollection ?? view.traitCollection
    }

    private func configureDropShadowHost(
        _ host: UIView,
        shadow: ElementShadow,
        frame: CGRect,
        cornerRadius: CGFloat
    ) {
        host.frame = frame
        host.layer.cornerRadius = cornerRadius
        host.layer.shadowColor = shadow.color.withAlphaComponent(shadow.opacity).cgColor
        host.layer.shadowOffset = CGSize(width: shadow.x, height: shadow.y)
        host.layer.shadowRadius = shadow.blur / 2
        host.layer.shadowOpacity = 1.0
        host.layer.masksToBounds = false
        setSigmaShadowPathSynchronously(for: host, bounds: host.bounds, cornerRadius: cornerRadius)
    }

    private func setSigmaShadowPathSynchronously(
        for view: UIView,
        bounds: CGRect,
        cornerRadius: CGFloat
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        view.layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cornerRadius
        ).cgPath
    }

    private func shadowHostIdentifier(for view: UIView, index: Int) -> String {
        "ElementsConfigShadowHost.\(Unmanaged.passUnretained(view).toOpaque()).\(index)"
    }

    private func shadowHostPrefix(for view: UIView) -> String {
        "ElementsConfigShadowHost.\(Unmanaged.passUnretained(view).toOpaque())"
    }

    private func shadowHosts(for view: UIView) -> [UIView] {
        guard let superview = view.superview else { return [] }
        let prefix = shadowHostPrefix(for: view)
        return superview.subviews
            .filter { $0.accessibilityIdentifier?.hasPrefix(prefix) == true }
            .sorted {
                ($0.accessibilityIdentifier ?? "") < ($1.accessibilityIdentifier ?? "")
            }
    }

    private func removeShadowHosts(for view: UIView) {
        shadowHosts(for: view).forEach { $0.removeFromSuperview() }
    }
}

struct ElementShadow {
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
    let color: UIColor
    let opacity: CGFloat
}

enum ElementShadowPresets {
    static func primaryButtonDropShadows(traitCollection: UITraitCollection) -> [ElementShadow] {
        let primary = Colors.shared.primary.resolvedColor(with: traitCollection)
        return [
            ElementShadow(
                x: 0,
                y: 10,
                blur: 24,
                color: primary,
                opacity: Colors.Shadow.primaryDropOpacityLarge
            ),
            ElementShadow(
                x: 0,
                y: 2,
                blur: 6,
                color: primary,
                opacity: Colors.Shadow.primaryDropOpacitySmall
            )
        ]
    }

    static var primaryButtonDropShadows: [ElementShadow] {
        primaryButtonDropShadows(traitCollection: UITraitCollection.current)
    }

    static var primaryButtonInnerShadow: ElementShadow {
        ElementShadow(
            x: 0,
            y: 0,
            blur: 5,
            color: .white,
            opacity: Colors.Shadow.innerHighlightOpacity
        )
    }

    static func addAccountOptionCardDropShadow(traitCollection: UITraitCollection) -> ElementShadow {
        let isDark = traitCollection.userInterfaceStyle == .dark
        return ElementShadow(
            x: 0,
            y: 2,
            blur: isDark ? 6 : 12,
            color: .black,
            opacity: isDark ? 0.25 : 0.06
        )
    }

    static func passcodeKeyDropShadow(traitCollection: UITraitCollection) -> ElementShadow {
        let isDark = traitCollection.userInterfaceStyle == .dark
        return ElementShadow(
            x: 0,
            y: isDark ? 4 : 2,
            blur: isDark ? 10 : 12,
            color: .black,
            opacity: isDark ? 0.35 : 0.06
        )
    }
}
