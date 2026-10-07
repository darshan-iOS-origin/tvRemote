//
//  FireTVController.swift
//  tvRemoteDemo
//
//  Amazon Fire TV over its local HTTPS API on port 8080 (the "Lightning" API of Amazon's own remote app),
//  after the PIN sign-in in FireTVPairing.swift. Every request carries `X-Api-Key` and `X-Client-Token`.
//  Calls (hms-firetv, MIT, Copyright (c) 2026 HMS Homelab; no code copied):
//    - keys: `POST /v1/FireTV?action=dpad_up|dpad_down|dpad_left|dpad_right|select|back|home|menu`
//    - play: `POST /v1/media?action=play`
//    - apps: `GET /v1/FireTV/appsV2`, launch with `POST /v1/FireTV/app/<package>`
//    - wake: `POST http://<ip>:8009/apps/FireTVRemote`, plain HTTP, works while the device sleeps
//
//  The control is small: no volume, mute, power, channels, inputs or text (the only text call opens the
//  TV's own keyboard). UNVERIFIED on a real Fire TV, the whole controller.
//

import Foundation

nonisolated struct FireTVController: TVController {
    let platform = TVPlatform.fireTV

    private let host: String
    private let client: HTTPRequesting
    private let store: TVTokenStoring
    private let timeout: TimeInterval

    init(
        host: String,
        client: HTTPRequesting = LocalHTTPClient(),
        store: TVTokenStoring = KeychainTokenStore(),
        timeout: TimeInterval = 5
    ) {
        self.host = host
        self.client = client
        self.store = store
        self.timeout = timeout
    }

    /// Checks that a token is saved and that the TV accepts it (the app list needs the token). Throws
    /// `TVError.notPaired` without one, or when the TV no longer accepts it.
    func connect() async throws {
        _ = try await request(path: "v1/FireTV/appsV2", method: "GET")
    }

    func send(_ key: KeyCommand) async throws {
        guard let path = Self.path(for: key) else {
            throw TVError.unsupportedKey(key)
        }
        _ = try await request(path: path, method: "POST")
    }

    /// The installed apps from `appsV2`. If the answer cannot be read, a small fixed list is used.
    func apps() async throws -> [TVApp] {
        let response = try await request(path: "v1/FireTV/appsV2", method: "GET")
        let found = Self.parseApps(response.data)
        return found.isEmpty ? Self.catalog : found
    }

    func launch(_ app: TVApp) async throws {
        guard let package = app.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: ".-_"))) else {
            throw TVError.appUnavailable
        }
        do {
            _ = try await request(path: "v1/FireTV/app/\(package)", method: "POST")
        } catch TVError.badResponse {
            throw TVError.appUnavailable
        }
    }

    func disconnect() async {}

    // MARK: - Keys

    /// The request path for a key, nil when the Fire TV has no call for it. Play / Pause is the media
    /// `play` call, which is expected to toggle (UNVERIFIED).
    static func path(for key: KeyCommand) -> String? {
        switch key {
        case .up: return "v1/FireTV?action=dpad_up"
        case .down: return "v1/FireTV?action=dpad_down"
        case .left: return "v1/FireTV?action=dpad_left"
        case .right: return "v1/FireTV?action=dpad_right"
        case .select: return "v1/FireTV?action=select"
        case .back: return "v1/FireTV?action=back"
        case .home: return "v1/FireTV?action=home"
        case .menu: return "v1/FireTV?action=menu"
        case .playPause: return "v1/media?action=play"
        default: return nil
        }
    }

    static func supports(_ key: KeyCommand) -> Bool {
        path(for: key) != nil
    }

    // MARK: - Apps

    /// Two packages named in the community documentation, and two from memory (UNVERIFIED).
    static let catalog = [
        TVApp(id: "com.netflix.ninja", name: "Netflix"),
        TVApp(id: "com.disney.disneyplus", name: "Disney+"),
        TVApp(id: "com.amazon.firetv.youtube", name: "YouTube"),
        TVApp(id: "com.amazon.avod", name: "Prime Video")
    ]

    private static let nameKeys = ["name", "appName", "title", "label", "displayName", "app_name"]
    private static let packageKeys = ["packageName", "package", "appId", "id", "pkg", "app_id"]

    /// Reads the app list. The answer's shape is not documented, so this takes the first array of objects
    /// it finds (the answer itself, or a value of it) and reads the first of several likely name and
    /// package fields from each. Public for checking.
    static func parseApps(_ data: Data) -> [TVApp] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var list: [[String: Any]] = []
        if let array = json as? [[String: Any]] {
            list = array
        } else if let object = json as? [String: Any] {
            for key in object.keys.sorted() {
                if let array = object[key] as? [[String: Any]] {
                    list = array
                    break
                }
            }
        }
        var seen = Set<String>()
        return list.compactMap { item in
            guard let package = packageKeys.compactMap({ item[$0] as? String }).first(where: { !$0.isEmpty }),
                  let name = nameKeys.compactMap({ item[$0] as? String }).first(where: { !$0.isEmpty }),
                  seen.insert(package).inserted else {
                return nil
            }
            return TVApp(id: package, name: name)
        }
    }

    // MARK: - Wake

    /// Wakes a sleeping Fire TV: a plain-HTTP call to port 8009 that works while it sleeps. No MAC address
    /// is needed. Throws `TVError.wakeFailed` when nothing answers.
    static func wake(host: String, client: HTTPRequesting = LocalHTTPClient()) async throws {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let url = URL(string: "http://\(host):\(FireTVAPI.wakePort)/apps/FireTVRemote") else {
            throw TVError.wakeFailed
        }
        let response: HTTPResponse
        do {
            response = try await client.send(HTTPRequest(url: url, method: "POST", timeout: 5))
        } catch {
            throw TVError.wakeFailed
        }
        guard (200...299).contains(response.statusCode) else {
            throw TVError.wakeFailed
        }
    }

    // MARK: - Requests

    private func request(path: String, method: String) async throws -> HTTPResponse {
        guard LocalTrustPolicy.shouldTrust(host: host) else { throw TVError.unreachable }
        guard let token = store.token(for: host, platform: .fireTV) else { throw TVError.notPaired }
        guard let url = FireTVAPI.url(host: host, path: path) else { throw TVError.unreachable }

        let response: HTTPResponse
        do {
            response = try await client.send(HTTPRequest(
                url: url, method: method, headers: FireTVAPI.headers(token: token), timeout: timeout
            ))
        } catch {
            throw ApprovalWait.tvError(from: error)
        }
        switch response.statusCode {
        case 200...299: return response
        // The token was refused, for example after the TV was reset: the phone has to pair again.
        case 401, 403: throw TVError.notPaired
        default: throw TVError.badResponse
        }
    }
}
