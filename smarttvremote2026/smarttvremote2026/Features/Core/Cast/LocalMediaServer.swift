//
//  LocalMediaServer.swift
//  tvRemoteDemo
//
//  A tiny web server on the phone, for casting. A TV that is told to play a web address fetches the
//  file itself, so the phone has to serve it. It uses Apple's `NWListener` and no package.
//
//  Safety (CLAUDE.md, local network only): files are only served under an unguessable random token,
//  only to a private local address, and only while casting. Nothing leaves the local network.
//  File names are never logged.
//
//  UNVERIFIED on a device: the listener on Wi-Fi, and the TV's range requests.
//

import Foundation
import Network
import Security

nonisolated final class LocalMediaServer: @unchecked Sendable {
    /// What a request for part of a file asks for.
    enum ByteRange: Equatable {
        case whole
        /// First and last byte, both included.
        case partial(first: Int64, last: Int64)
        case unsatisfiable
    }

    private struct Served {
        var fileURL: URL
        var contentType: String
    }

    private static let chunkSize = 256 * 1024
    private static let maxRequestBytes = 16 * 1024

    private let queue = DispatchQueue(label: "tvremote.cast.server")
    private let lock = NSLock()
    private var listener: NWListener?
    private var files: [String: Served] = [:]

    // MARK: - Lifecycle

    /// Starts listening on a free port and returns it. Throws `CastMediaError.serverFailed`.
    func start() async throws -> UInt16 {
        lock.lock()
        if let existing = listener, let port = existing.port?.rawValue {
            lock.unlock()
            return port
        }
        lock.unlock()

        let parameters = NWParameters.tcp
        #if DEBUG
        // The iOS Simulator uses the Mac's network, which can be wired. Never cellular.
        parameters.prohibitedInterfaceTypes = [.cellular]
        #else
        parameters.requiredInterfaceType = .wifi
        #endif
        let newListener: NWListener
        do {
            newListener = try NWListener(using: parameters)
        } catch {
            throw CastMediaError.serverFailed
        }
        newListener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            newListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let port = newListener.port?.rawValue {
                        once.resume(returning: port)
                    } else {
                        once.resume(throwing: CastMediaError.serverFailed)
                    }
                case .failed, .cancelled:
                    once.resume(throwing: CastMediaError.serverFailed)
                default:
                    break
                }
            }
            newListener.start(queue: queue)
        }
        lock.lock()
        listener = newListener
        lock.unlock()
        return port
    }

    /// Stops listening and forgets every file. The files themselves are removed by `MediaPreparer`.
    func stop() {
        lock.lock()
        let current = listener
        listener = nil
        files = [:]
        lock.unlock()
        current?.cancel()
    }

    /// Makes a file available and returns the path to ask for, for example `/m/9f2c….mp4`.
    func register(fileURL: URL, contentType: String) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        lock.lock()
        files[token] = Served(fileURL: fileURL, contentType: contentType)
        lock.unlock()
        let ext = fileURL.pathExtension
        return "/m/" + token + (ext.isEmpty ? "" : "." + ext)
    }

    // MARK: - Requests

    private func accept(_ connection: NWConnection) {
        // Only a private local address may ask for anything (LocalTrustPolicy: private IPv4 addresses).
        guard case .hostPort(let host, _) = connection.endpoint,
              case .ipv4(let address) = host,
              LocalTrustPolicy.shouldTrust(host: Self.string(from: address)) else {
            connection.cancel()
            return
        }
        connection.start(queue: queue)
        readRequest(on: connection, received: Data())
    }

    private static func string(from address: IPv4Address) -> String {
        address.rawValue.map { String($0) }.joined(separator: ".")
    }

    private func readRequest(on connection: NWConnection, received: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
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
        let lines = head.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count >= 2 else {
            send(status: "400 Bad Request", on: connection)
            return
        }
        let method = String(parts[0])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
        }

        if method == "OPTIONS" {
            send(status: "204 No Content", on: connection)
            return
        }
        guard method == "GET" || method == "HEAD" else {
            send(status: "405 Method Not Allowed", on: connection)
            return
        }
        guard let served = served(forPath: String(parts[1])),
              let size = (try? FileManager.default.attributesOfItem(atPath: served.fileURL.path)[.size] as? NSNumber)?.int64Value else {
            send(status: "404 Not Found", on: connection)
            return
        }

        // A DLNA renderer (Samsung, LG) asks for these headers by sending `getcontentFeatures.dlna.org: 1`.
        // UNVERIFIED which headers each TV insists on. Google Cast ignores them.
        let dlna = headers["getcontentfeatures.dlna.org"] == "1"
        switch Self.byteRange(header: headers["range"], total: size) {
        case .unsatisfiable:
            send(status: "416 Range Not Satisfiable", extra: ["Content-Range": "bytes */\(size)"], on: connection)
        case .whole:
            sendFile(served, first: 0, last: size - 1, total: size, partial: false, headOnly: method == "HEAD", dlna: dlna, on: connection)
        case .partial(let first, let last):
            sendFile(served, first: first, last: last, total: size, partial: true, headOnly: method == "HEAD", dlna: dlna, on: connection)
        }
    }

    private func served(forPath path: String) -> Served? {
        // "/m/<token>" or "/m/<token>.<extension>", without a query.
        let clean = path.split(separator: "?").first.map(String.init) ?? path
        guard clean.hasPrefix("/m/") else { return nil }
        let name = String(clean.dropFirst(3))
        let token = name.split(separator: ".").first.map(String.init) ?? name
        lock.lock()
        defer { lock.unlock() }
        return files[token]
    }

    /// Reads a `Range: bytes=…` header. Public for checking: the arithmetic is the part most easy to get wrong.
    static func byteRange(header: String?, total: Int64) -> ByteRange {
        guard let header, header.lowercased().hasPrefix("bytes=") else { return .whole }
        let spec = header.dropFirst("bytes=".count).split(separator: ",").first.map(String.init) ?? ""
        let pieces = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard pieces.count == 2, total > 0 else { return total == 0 ? .whole : .unsatisfiable }

        let startText = pieces[0].trimmingCharacters(in: .whitespaces)
        let endText = pieces[1].trimmingCharacters(in: .whitespaces)
        if startText.isEmpty {
            // "-N": the last N bytes.
            guard let count = Int64(endText), count > 0 else { return .unsatisfiable }
            return .partial(first: max(total - count, 0), last: total - 1)
        }
        guard let first = Int64(startText), first >= 0, first < total else { return .unsatisfiable }
        if endText.isEmpty {
            return .partial(first: first, last: total - 1)
        }
        guard let last = Int64(endText), last >= first else { return .unsatisfiable }
        return .partial(first: first, last: min(last, total - 1))
    }

    // MARK: - Responses

    private func send(status: String, extra: [String: String] = [:], on connection: NWConnection) {
        var headers = Self.commonHeaders
        headers["Content-Length"] = "0"
        for (key, value) in extra { headers[key] = value }
        let text = "HTTP/1.1 \(status)\r\n" + headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n") + "\r\n\r\n"
        connection.send(content: Data(text.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    private static var commonHeaders: [String: String] {
        [
            "Accept-Ranges": "bytes",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Range",
            "Access-Control-Expose-Headers": "Content-Length, Content-Range",
            "Cache-Control": "no-store",
            "Connection": "close"
        ]
    }

    private func sendFile(_ served: Served, first: Int64, last: Int64, total: Int64, partial: Bool, headOnly: Bool, dlna: Bool, on connection: NWConnection) {
        var headers = Self.commonHeaders
        headers["Content-Type"] = served.contentType
        headers["Content-Length"] = String(last - first + 1)
        if dlna {
            headers["transferMode.dlna.org"] = "Streaming"
            headers["contentFeatures.dlna.org"] = "DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000"
        }
        if partial {
            headers["Content-Range"] = "bytes \(first)-\(last)/\(total)"
        }
        let status = partial ? "206 Partial Content" : "200 OK"
        let text = "HTTP/1.1 \(status)\r\n" + headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n") + "\r\n\r\n"

        connection.send(content: Data(text.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, !headOnly, let handle = try? FileHandle(forReadingFrom: served.fileURL) else {
                connection.cancel()
                return
            }
            do {
                try handle.seek(toOffset: UInt64(first))
            } catch {
                try? handle.close()
                connection.cancel()
                return
            }
            self?.stream(handle, remaining: last - first + 1, on: connection)
        })
    }

    /// Sends the file in pieces, each after the one before has been taken, so a slow TV never makes
    /// the phone hold the whole file in memory.
    private func stream(_ handle: FileHandle, remaining: Int64, on connection: NWConnection) {
        guard remaining > 0 else {
            try? handle.close()
            connection.cancel()
            return
        }
        let data = handle.readData(ofLength: Int(min(Int64(Self.chunkSize), remaining)))
        guard !data.isEmpty else {
            try? handle.close()
            connection.cancel()
            return
        }
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if error != nil {
                try? handle.close()
                connection.cancel()
                return
            }
            self?.stream(handle, remaining: remaining - Int64(data.count), on: connection)
        })
    }
}

/// Resumes a continuation once, however many times the state callback fires.
private nonisolated final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Value) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let taken = continuation
        continuation = nil
        return taken
    }
}
