import UIKit

enum CommonFont: String {
    case thin = "SFProText-Thin"
    case light = "SFProText-Light"
    case regular = "SFProText-Regular"
    case medium = "SFProText-Medium"
    case semibold = "SFProText-Semibold"
    case bold = "SFProText-Bold"
    case heavy = "SFProText-Heavy"
    case black = "SFProText-Black"

    func font(ofSize size: CGFloat) -> UIFont {
        UIFont(name: rawValue, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
    }

    private var fallbackWeight: UIFont.Weight {
        switch self {
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}
