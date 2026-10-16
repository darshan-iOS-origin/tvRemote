import Foundation

/// The one connection and the one pairing helper for the whole app, so the TV connected on the
/// scan screen is the same one My Apps and the remote use. `mirror` lives as long as the app, so a screen
/// broadcast reaches the TV even when the Mirror screen is closed.
enum AppServices {
    static let connection = ConnectionManager()
    static let pairing = PairingManager()
    static let mirror = MirrorController()
}
