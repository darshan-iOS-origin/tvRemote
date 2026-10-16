//
//  HTTPRequesting.swift
//  tvRemoteDemo
//

import Foundation

nonisolated struct HTTPRequest: Sendable, Equatable {
    var url: URL
    var method: String
    var headers: [String: String] = [:]
    var body: Data?
    var timeout: TimeInterval
}

nonisolated struct HTTPResponse: Sendable, Equatable {
    var statusCode: Int
    var data: Data
    /// The response headers, with lower-case names. Empty when nobody asked for them.
    var headers: [String: String] = [:]
}

/// A request with any method and a body, unlike `HTTPDataFetching` which only reads. Pairing needs
/// PUT requests.
nonisolated protocol HTTPRequesting: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// Which hosts may present a certificate we cannot verify.
nonisolated enum LocalTrustPolicy {
    /// TVs use self-signed certificates on the local network. Trust one only for a private or
    /// link-local IPv4 address, never for a name or a public address (CLAUDE.md, Networking).
    static func shouldTrust(host: String) -> Bool {
        #if DEBUG
        // Debug builds also accept exactly 127.0.0.1, so the iOS Simulator can reach the Android TV
        // emulator's forwarded ports on the same Mac (README, "Testing with the Android TV
        // emulator"). On a phone it is the phone itself. Release builds never accept it.
        if host == "127.0.0.1" {
            return true
        }
        #endif
        return IPv4.isPrivateOrLinkLocal(host)
    }
}

/// Accepts a TV's self-signed certificate, but only under `LocalTrustPolicy`.
nonisolated final class LocalTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = space.serverTrust,
              LocalTrustPolicy.shouldTrust(host: space.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

nonisolated struct LocalHTTPClient: HTTPRequesting {
    private let session: URLSession

    /// Pass a `session` in tests. The default one trusts local TVs' certificates.
    init(session: URLSession? = nil) {
        self.session = session ?? URLSession(
            configuration: .ephemeral,
            delegate: LocalTrustDelegate(),
            delegateQueue: nil
        )
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        // A header such as `Cookie` is sent exactly as given. The session never keeps cookies by itself.
        urlRequest.httpShouldHandleCookies = false
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw TVDiscoveryError.badResponse
        }
        var headers: [String: String] = [:]
        for (name, value) in http.allHeaderFields {
            if let name = name as? String, let value = value as? String {
                headers[name.lowercased()] = value
            }
        }
        return HTTPResponse(statusCode: http.statusCode, data: data, headers: headers)
    }
}
