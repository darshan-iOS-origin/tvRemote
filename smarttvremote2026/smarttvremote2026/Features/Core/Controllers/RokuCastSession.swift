//
//  RokuCastSession.swift
//  tvRemoteDemo
//
//  Casts to a Roku with its "Play on Roku" channel (application id 15985):
//  `POST http://<ip>:8060/input/15985?t=<type>&u=<web address>&videoName=<title>&videoFormat=<format>`.
//  The id and the `t`, `u`, `videoName`, `videoFormat` parameters come from third-party descriptions of
//  the call (a forum post and a home-automation project). UNVERIFIED, from memory: `t=a` for audio
//  and `t=p` for a photo. Roku's own documentation could not be read here. The Roku downloads the
//  file from the phone's web server, as with Google Cast. Addresses are never logged.
//

import Foundation

nonisolated struct RokuCastSession: CastSession {
    private let host: String
    private let client: HTTPRequesting

    init(host: String, client: HTTPRequesting = LocalHTTPClient()) {
        self.host = host
        self.client = client
    }

    /// Plays a photo, video or song. Throws `TVError.castFailed` if the Roku refuses it.
    func play(url: URL, contentType: String, title: String) async throws {
        guard let endpoint = Self.playURL(host: host, media: url, contentType: contentType, title: title) else {
            throw TVError.castFailed
        }
        try await post(endpoint)
    }

    /// `Play` toggles between playing and paused on a Roku.
    func pause() async throws {
        try await key("Play")
    }

    func resume() async throws {
        try await key("Play")
    }

    /// Roku has no stop call for this channel, so Home leaves it.
    func stop() async throws {
        try await key("Home")
    }

    func close() async {}

    // MARK: - Requests

    private func key(_ name: String) async throws {
        guard let url = URL(string: "http://\(host):\(ControlPorts.rokuECP)/keypress/\(name)") else {
            throw TVError.unreachable
        }
        try await post(url)
    }

    private func post(_ url: URL) async throws {
        guard LocalTrustPolicy.shouldTrust(host: host) else {
            throw TVError.unreachable
        }
        let response: HTTPResponse
        do {
            response = try await client.send(HTTPRequest(url: url, method: "POST", timeout: 8))
        } catch {
            throw ApprovalWait.tvError(from: error)
        }
        guard (200...299).contains(response.statusCode) else {
            throw TVError.castFailed
        }
    }

    // MARK: - Address

    /// The "Play on Roku" call for a file. Public for checking.
    static func playURL(host: String, media: URL, contentType: String, title: String) -> URL? {
        let type: String
        var query: [(String, String)] = []
        if contentType.hasPrefix("image/") {
            type = "p"
        } else if contentType.hasPrefix("audio/") {
            type = "a"
        } else {
            type = "v"
            query.append(("videoFormat", videoFormat(for: contentType)))
        }
        let pairs = [("t", type), ("u", media.absoluteString), ("videoName", title)] + query
        let text = pairs.map { "\($0.0)=\(encode($0.1))" }.joined(separator: "&")
        return URL(string: "http://\(host):\(ControlPorts.rokuECP)/input/15985?\(text)")
    }

    /// The `videoFormat` values named in the third-party descriptions: mp4, mkv, mov and wmv.
    static func videoFormat(for contentType: String) -> String {
        switch contentType.lowercased() {
        case "video/quicktime": return "mov"
        case "video/x-matroska": return "mkv"
        case "video/x-ms-wmv": return "wmv"
        default: return "mp4"
        }
    }

    /// Everything but letters, digits and `-._~` is percent-encoded, so `&`, `=` and `:` inside the
    /// web address cannot break the query.
    private static func encode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
