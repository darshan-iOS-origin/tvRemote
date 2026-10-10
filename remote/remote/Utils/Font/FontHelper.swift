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

    /// The font at `size` points, times `DeviceLayout.padFontScale` (1 on iPhone, so iPhone sizes do not change).
    func font(ofSize size: CGFloat) -> UIFont {
        let scaled = (size * DeviceLayout.padFontScale * 2).rounded() / 2
        return UIFont(name: rawValue, size: scaled) ?? .systemFont(ofSize: scaled, weight: fallbackWeight)
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
