import UIKit

/// A bold title with a row of keys under it: TV, Navigation, Input, Playback, Colours and More.
final class RemoteSectionView: UIStackView {

    /// Figma trims text to its cap height, so a title's line box has about 4.3 pt of padding above and
    /// below the capitals. These spacings (18 pt under the title, 25 pt between sections in the design)
    /// are shortened by that padding to give the same distances.
    static let titleLinePadding: CGFloat = 4.3
    static let sectionSpacing: CGFloat = 25 - titleLinePadding

    init(title: String, content: UIView) {
        super.init(frame: .zero)
        axis = .vertical
        alignment = .fill
        spacing = 18 - Self.titleLinePadding

        let label = UILabel()
        label.text = title
        label.font = CommonFont.bold.font(ofSize: 18)
        label.textColor = CommonColor.white.color
        addArrangedSubview(label)
        addArrangedSubview(content)
    }

    required init(coder: NSCoder) {
        fatalError("RemoteSectionView is built in code")
    }
}
