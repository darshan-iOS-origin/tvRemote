//
//  ApprovalWait.swift
//  tvRemoteDemo
//
//  Samsung and LG show an Allow / Accept prompt on the TV the first time. The connection is only
//  good once the user answers it, which can take a while, so connecting waits for the TV's verdict.
//

import Foundation

nonisolated enum ApprovalWait {
    enum Verdict: Sendable {
        case success
        case failure(TVError)
        case keepWaiting
    }

    /// How long the TV may wait for the user to answer its prompt.
    static let defaultTimeout: TimeInterval = 30

    /// Starts listening through `begin`, then returns on the first `.success`, throws on the first
    /// `.failure`, and throws `TVError.awaitingApproval` if nothing decides within `timeout`.
    static func wait<Event: Sendable>(
        timeout: TimeInterval = defaultTimeout,
        begin: (_ emit: @escaping @Sendable (Event) -> Void) -> Void,
        judge: (Event) -> Verdict
    ) async throws {
        var made: AsyncStream<Event>.Continuation?
        let events = AsyncStream<Event> { made = $0 }
        guard let continuation = made else {
            throw TVError.unreachable
        }
        begin { continuation.yield($0) }

        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            continuation.finish()
        }
        defer {
            timer.cancel()
            continuation.finish()
        }

        for await event in events {
            switch judge(event) {
            case .success: return
            case .failure(let error): throw error
            case .keepWaiting: continue
            }
        }
        throw TVError.awaitingApproval
    }

    /// Maps a library or URLSession error to a `TVError`.
    static func tvError(from error: Error) -> TVError {
        if let tvError = error as? TVError {
            return tvError
        }
        if (error as? URLError)?.code == .timedOut {
            return .timedOut
        }
        return .unreachable
    }
}
