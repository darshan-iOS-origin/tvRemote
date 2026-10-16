import UIKit

/// The title row at the top of every tab screen. The title is centred `titleCenterY` below the safe area top, so it
/// stays at the same height when the user switches tabs. Remote and Keyboard build their header with
/// `height`; Favourites uses `titleCenterY` in code; Settings and My Apps use the same 30 pt (centre Y of the
/// title = safe area top + 30) in `Main.storyboard`.
enum TabHeader {

    /// Height of the header row (the 40 pt header buttons of Remote and Keyboard fit in it).
    static let height: CGFloat = 60

    /// Distance from the safe area top to the middle of the title.
    static var titleCenterY: CGFloat { height / 2 }
}
