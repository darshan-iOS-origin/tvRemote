//
//  LocalNetworkAuthorizer.swift
//  tvRemoteDemo
//

import Foundation
import Network
import UIKit

nonisolated enum LocalNetworkAuthorization: Sendable, Equatable {
    case granted
    case denied
    /// No decision within the timeout. The caller should carry on: the first real network use
    /// (the scan) shows the system prompt if it is still needed.
    case undetermined
}

nonisolated protocol LocalNetworkAuthorizing: Sendable {
    func requestAuthorization() async -> LocalNetworkAuthorization
}

nonisolated enum LocalNetworkAuthorizationClassifier {
    /// `kDNSServiceErr_PolicyDenied` from dns_sd.h. It is the error `NWBrowser` reports while
    /// Local Network access is refused.
    static let policyDeniedCode: Int32 = -65570

    /// Returns `.denied` for the browser states that mean "refused", and nil while there is
    /// nothing to conclude. A granted result is never taken from a browser state: it needs our
    /// own advertised service to show up in the browse results.
    static func classify(_ state: NWBrowser.State) -> LocalNetworkAuthorization? {
        switch state {
        case .failed:
            return .denied
        case .waiting(let error):
            if case .dns(let code) = error, code == policyDeniedCode {
                return .denied
            }
            return nil
        default:
            return nil
        }
    }
}

/// iOS has no API to request Local Network access. The system prompt appears the first time an
/// app touches the local network. This class does that on purpose: it advertises a Bonjour service
/// briefly and browses for it. The service showing up means access is granted.
///
/// UNVERIFIED on a real device. The technique is recalled from Apple developer-forum guidance
/// ("Local Network Privacy FAQ") and community sample code. Check: the prompt appears, "Allow"
/// gives `.granted`, and "Don't Allow" gives `.denied`.
nonisolated struct NWBrowserLocalNetworkAuthorizer: LocalNetworkAuthorizing {
    var timeout: TimeInterval = 15

    func requestAuthorization() async -> LocalNetworkAuthorization {
        await withCheckedContinuation { continuation in
            let attempt = AuthorizationAttempt(timeout: timeout) { continuation.resume(returning: $0) }
            attempt.start()
        }
    }
}

/// One authorization attempt. `finish` is safe to call from any thread and only the first call counts.
private nonisolated final class AuthorizationAttempt: @unchecked Sendable {
    // These two types must be listed under NSBonjourServices in Info.plist.
    private static let serviceType = "_lnp._tcp"
    private static let serviceName = "LocalNetworkAuthorization"

    /// While the system prompt is showing the app is not active, so a "denied" report is not final.
    private static let deniedConfirmationDelay: TimeInterval = 2

    private let queue = DispatchQueue(label: "tvremote.localnetwork.authorization")
    private let lock = NSLock()
    private let timeout: TimeInterval
    private var completion: ((LocalNetworkAuthorization) -> Void)?
    private var isFinished = false
    private var isDeniedCheckScheduled = false
    private var browser: NWBrowser?
    private var service: NetService?
    /// Set when the app leaves the active state during this attempt. That is the system alert.
    private var didShowAlert = false
    private var resignObserver: NSObjectProtocol?
    /// The callbacks only hold this object weakly, so it keeps itself alive until it finishes.
    private var keepAlive: AuthorizationAttempt?

    init(timeout: TimeInterval, completion: @escaping (LocalNetworkAuthorization) -> Void) {
        self.timeout = timeout
        self.completion = completion
    }

    func start() {
        lock.lock()
        keepAlive = self
        lock.unlock()

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handle(results)
        }
        setBrowser(browser)
        browser.start(queue: queue)

        // NetService needs the main run loop.
        ThreadManager.onMain { [weak self] in
            guard let self, !self.finished else { return }
            let service = NetService(domain: "local.", type: "\(Self.serviceType).", name: Self.serviceName, port: 1100)
            self.setService(service)
            service.publish()
        }

        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish(.undetermined)
        }

        // The Local Network alert takes the app inactive. There is no status API to ask beforehand.
        ThreadManager.onMain { [weak self] in
            guard let self else { return }
            let observer = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.noteAlertShown()
            }
            self.storeResignObserver(observer)
        }
    }

    private func storeResignObserver(_ observer: NSObjectProtocol) {
        lock.lock()
        if isFinished {
            lock.unlock()
            NotificationCenter.default.removeObserver(observer)
            return
        }
        resignObserver = observer
        lock.unlock()
    }

    private func noteAlertShown() {
        lock.lock()
        let alreadyLogged = didShowAlert || isFinished
        if !alreadyLogged {
            didShowAlert = true
        }
        lock.unlock()
        guard !alreadyLogged else { return }
        PermissionLogger.triggered("Local Network")
    }

    private func handle(_ state: NWBrowser.State) {
        if LocalNetworkAuthorizationClassifier.classify(state) == .denied {
            scheduleDeniedCheck()
        }
    }

    private func handle(_ results: Set<NWBrowser.Result>) {
        let foundOwnService = results.contains { result in
            if case let .service(name, _, _, _) = result.endpoint {
                return name == Self.serviceName
            }
            return false
        }
        if foundOwnService {
            finish(.granted)
        }
    }

    /// Reports `.denied` only once the app is active again, and only if access was not granted meanwhile.
    private func scheduleDeniedCheck() {
        lock.lock()
        let alreadyScheduled = isDeniedCheckScheduled
        isDeniedCheckScheduled = true
        lock.unlock()
        guard !alreadyScheduled else { return }
        checkDeniedAfterDelay()
    }

    private func checkDeniedAfterDelay() {
        Task { @MainActor [weak self] in
            while let self, !self.finished {
                try? await ThreadManager.delay(seconds: Self.deniedConfirmationDelay)
                guard !self.finished else { return }
                if UIApplication.shared.applicationState == .active {
                    self.finish(.denied)
                    return
                }
            }
        }
    }

    private var finished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isFinished
    }

    private func setBrowser(_ browser: NWBrowser) {
        lock.lock()
        self.browser = browser
        lock.unlock()
    }

    private func setService(_ service: NetService) {
        lock.lock()
        self.service = service
        lock.unlock()
    }

    private func finish(_ result: LocalNetworkAuthorization) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let completion = self.completion
        self.completion = nil
        let browser = self.browser
        let service = self.service
        let prompted = didShowAlert
        let observer = resignObserver
        resignObserver = nil
        keepAlive = nil
        lock.unlock()

        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        browser?.cancel()
        if let service {
            ThreadManager.onMain { service.stop() }
        }
        PermissionLogger.localNetwork(result, prompted: prompted)
        completion?(result)
    }
}
