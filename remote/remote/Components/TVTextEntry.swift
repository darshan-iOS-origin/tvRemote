import UIKit

/// The header keyboard button, shared by the Remote and Keyboard tabs: opens the "Type on TV" box and sends
/// what is typed to the connected TV, then presses Enter on it (search boxes, sign-in fields).
@MainActor
enum TVTextEntry {

    /// Checks there is a TV that can take typed text, then shows the box over `presenter`.
    /// - `onNeedConnection`: no TV is connected, so the screen should ask the user to connect one.
    /// - `onError`: something to tell the user, in plain words.
    static func present(
        from presenter: UIViewController,
        onNeedConnection: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        Task { [weak presenter] in
            guard let device = await AppServices.connection.activeDevice else {
                onNeedConnection()
                return
            }
            guard ConnectionManager.canType(device.platform) else {
                onError("Typing is not available for this TV yet.")
                return
            }
            guard let presenter else { return }
            let host = presenter.tabBarController ?? presenter
            guard presenter.presentedViewController == nil, host.presentedViewController == nil else { return }

            let dialog = TextInputAlertVC(title: "Type on TV", placeholder: "Type here", actionTitle: "Send")
            dialog.onSubmit = { text in
                Task {
                    do {
                        try await AppServices.connection.send(TextCommand.insert(text))
                        try await AppServices.connection.send(TextCommand.enter)
                    } catch let error as TVError {
                        LoggerManager.warning("Sending text failed: \(error)", category: "Keyboard")
                        onError(error.userMessage)
                    } catch {
                        onError(TVError.unreachable.userMessage)
                    }
                }
            }
            host.present(dialog, animated: true)
        }
    }
}
