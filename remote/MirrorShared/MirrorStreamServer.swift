//
//  MirrorStreamServer.swift
//  MirrorBroadcast (and the app's DEBUG Simulator test stream, `MirrorTestStream`)
//
//  A tiny web server in the broadcast extension: the TV fetches the live playlist and its segments from
//  here. Built like the app's `LocalMediaServer` (Apple's `NWListener`, no package), but it serves the
//  stream from memory instead of files.
//
//  Safety (local network only): everything is under an unguessable random token, only private IPv4
//  addresses are answered, only on Wi-Fi, and only while the broadcast runs. Nothing is logged but the
//  status of each request.
//

import Foundation
import Network
import os

nonisolated final class MirrorStreamServer: @unchecked Sendable {
    private static let maxRequestBytes = 16 * 1024

    private let wifiOnly: Bool
    private let allowLoopback: Bool

    private let log = Logger(subsystem: MirrorShared.extensionBundleID, category: "Server")
    private let queue = DispatchQueue(label: "mirror.server")
    private let lock = NSLock()
    private var listener: NWListener?
    private var token = ""
    private weak var segmenter: HLSLiveSegmenter?

    /// The broadcast extension uses the defaults. The DEBUG Simulator test passes `wifiOnly: false` (a Mac
    /// can be wired; cellular is still refused) and `allowLoopback: true` (so `127.0.0.1` works in Safari).
    init(wifiOnly: Bool = true, allowLoopback: Bool = false) {
        self.wifiOnly = wifiOnly
        self.allowLoopback = allowLoopback
    }

    /// Starts listening on a free port and calls back once with it, or with nil if it can't.
    func start(token: String, segmenter: HLSLiveSegmenter, completion: @escaping @Sendable (UInt16?) -> Void) {
        let parameters = NWParameters.tcp
        if wifiOnly {
            parameters.requiredInterfaceType = .wifi
        } else {
            parameters.prohibitedInterfaceTypes = [.cellular]
        }
        let newListener: NWListener
        do {
            newListener = try NWListener(using: parameters)
        } catch {
            completion(nil)
            return
        }
        lock.lock()
        self.token = token
        self.segmenter = segmenter
        listener = newListener
        lock.unlock()

        newListener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        let once = OnceFlag()
        newListener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if once.take() { completion(newListener.port?.rawValue) }
            case .failed(let error):
                self?.log.error("Listener failed: \(String(describing: error), privacy: .public)")
                if once.take() { completion(nil) }
            case .cancelled:
                if once.take() { completion(nil) }
            default:
                break
            }
        }
        newListener.start(queue: queue)
    }

    func stop() {
        lock.lock()
        let current = listener
        listener = nil
        lock.unlock()
        current?.cancel()
    }

    // MARK: - Requests

    private func accept(_ connection: NWConnection) {
        guard case .hostPort(let host, _) = connection.endpoint,
              case .ipv4(let address) = host,
              Self.isPrivate(address) || (allowLoopback && address.isLoopback) else {
            connection.cancel()
            return
        }
        connection.start(queue: queue)
        readRequest(on: connection, received: Data())
    }

    /// 10/8, 172.16/12 and 192.168/16: the addresses a TV on home Wi-Fi has.
    private static func isPrivate(_ address: IPv4Address) -> Bool {
        let bytes = [UInt8](address.rawValue)
        guard bytes.count == 4 else { return false }
        return bytes[0] == 10
            || (bytes[0] == 172 && (16...31).contains(bytes[1]))
            || (bytes[0] == 192 && bytes[1] == 168)
    }

    private func readRequest(on connection: NWConnection, received: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buffer = received
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                self.respond(to: String(decoding: buffer[..<end.lowerBound], as: UTF8.self), on: connection)
            } else if error != nil || isComplete || buffer.count > Self.maxRequestBytes {
                connection.cancel()
            } else {
                self.readRequest(on: connection, received: buffer)
            }
        }
    }

    private func respond(to head: String, on connection: NWConnection) {
        let requestLine = head.components(separatedBy: "\r\n").first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            send(status: "400 Bad Request", on: connection)
            return
        }
        let method = String(parts[0])
        if method == "OPTIONS" {
            send(status: "204 No Content", on: connection)
            return
        }
        guard method == "GET" || method == "HEAD" else {
            send(status: "405 Method Not Allowed", on: connection)
            return
        }
        guard let found = content(forPath: String(parts[1])) else {
            send(status: "404 Not Found", on: connection)
            return
        }
        send(status: "200 OK", body: found.body, contentType: found.contentType, headOnly: method == "HEAD", on: connection)
    }

    /// `/<token>/live.m3u8`, `/<token>/init.mp4` or `/<token>/seg<N>.m4s`, without a query.
    private func content(forPath path: String) -> (body: Data, contentType: String)? {
        let clean = path.split(separator: "?").first.map(String.init) ?? path
        let pieces = clean.split(separator: "/").map(String.init)
        lock.lock()
        let token = self.token
        let segmenter = self.segmenter
        lock.unlock()
        guard pieces.count == 2, !token.isEmpty, pieces[0] == token, let segmenter else { return nil }

        let name = pieces[1]
        if name == MirrorShared.playlistName {
            return segmenter.playlist().map { (body: $0, contentType: "application/vnd.apple.mpegurl") }
        }
        if name == MirrorShared.initSegmentName {
            return segmenter.initializationData().map { (body: $0, contentType: "video/mp4") }
        }
        if name.hasPrefix("seg"), name.hasSuffix(".m4s"),
           let sequence = Int(name.dropFirst(3).dropLast(4)) {
            return segmenter.segment(sequence: sequence).map { (body: $0, contentType: "video/mp4") }
        }
        return nil
    }

    // MARK: - Responses

    private static var commonHeaders: [String: String] {
        [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Range",
            "Access-Control-Expose-Headers": "Content-Length",
            "Cache-Control": "no-store",
            "Connection": "close"
        ]
    }

    private func send(status: String, body: Data = Data(), contentType: String? = nil, headOnly: Bool = false, on connection: NWConnection) {
        var headers = Self.commonHeaders
        headers["Content-Length"] = String(body.count)
        if let contentType {
            headers["Content-Type"] = contentType
        }
        let head = "HTTP/1.1 \(status)\r\n" + headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n") + "\r\n\r\n"
        var message = Data(head.utf8)
        if !headOnly {
            message.append(body)
        }
        connection.send(content: message, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// True the first time only, however many times the listener's state changes.
private nonisolated final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
