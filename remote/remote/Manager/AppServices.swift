import Foundation

/// The one connection and the one pairing helper for the whole app, so the TV connected on the
/// scan screen is the same one My Apps and the remote use.
enum AppServices {
    static let connection = ConnectionManager()
    static let pairing = PairingManager()
}
