//
//  NWPortProber.swift
//  tvRemoteDemo
//

import Foundation
import Network

/// Checks whether a TCP port accepts a connection, over Wi-Fi only.
///
/// UNVERIFIED on a real device: a closed port is expected to show up as `.waiting` or `.failed`
/// (both are treated as "closed"), and a silent host as the timeout below.
nonisolated struct NWPortProber: PortProbing {
    func isOpen(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return false }

        let parameters = NWParameters.tcp
        #if DEBUG
        // The iOS Simulator uses the Mac's network, which can be wired. Never cellular.
        parameters.prohibitedInterfaceTypes = [.cellular]
        #else
        parameters.requiredInterfaceType = .wifi
        #endif
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)

        let attempt = ProbeAttempt(connection: connection)
        attempt.start(timeout: timeout)
        return await withTaskCancellationHandler {
            await attempt.result()
        } onCancel: {
            attempt.finish(false)
        }
    }
}

/// One probe. `finish` is safe to call from any thread and only the first call counts, so the
/// continuation is resumed exactly once (state callback, timeout and cancellation can race).
private nonisolated final class ProbeAttempt: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "tvremote.discovery.probe")
    private let lock = NSLock()
    private var outcome: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start(timeout: TimeInterval) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.finish(true)
            case .waiting, .failed, .cancelled:
                self?.finish(false)
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish(false)
        }
    }

    func result() async -> Bool {
        await withCheckedContinuation { continuation in
            install(continuation)
        }
    }

    func finish(_ value: Bool) {
        guard let waiting = record(value) else { return }
        connection.cancel()
        waiting.continuation?.resume(returning: value)
    }

    private func install(_ waiting: CheckedContinuation<Bool, Never>) {
        lock.lock()
        if let outcome {
            lock.unlock()
            waiting.resume(returning: outcome)
        } else {
            continuation = waiting
            lock.unlock()
        }
    }

    /// Stores the first outcome. Returns nil for every later call. On the first call it returns the
    /// continuation to resume, which is nil when nobody is waiting yet (`install` then delivers
    /// the stored outcome).
    private func record(_ value: Bool) -> Recorded? {
        lock.lock()
        defer { lock.unlock() }
        guard outcome == nil else { return nil }
        outcome = value
        let waiting = continuation
        continuation = nil
        return Recorded(continuation: waiting)
    }

    private struct Recorded {
        var continuation: CheckedContinuation<Bool, Never>?
    }
}
