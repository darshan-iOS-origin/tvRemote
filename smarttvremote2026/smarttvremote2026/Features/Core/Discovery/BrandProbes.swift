//
//  BrandProbes.swift
//  tvRemoteDemo
//
//  Proof that a host is a Samsung or an LG TV, for the subnet sweep. An open port alone never makes a TV
//  (a router or a dev server can open any port), so each probe asks the host something only that brand's TV
//  answers in a recognisable way, and nothing that could start a pairing prompt on the TV.
//
//  UNVERIFIED on real TVs, from memory and from the control code in this app:
//  - Samsung: `GET http://<ip>:8001/api/v2/` describes the TV in JSON (TVCommanderKit, and the call
//    `SamsungTizenController.hardwareAddresses` already makes).
//  - LG: an SSAP request sent before registering is answered with an error (`401 insufficient
//    permissions`), which only a webOS TV sends. Registering is what shows the Accept popup, so it is not
//    done here.
//

import Foundation

nonisolated protocol BrandProbing: Sendable {
    /// A Samsung Tizen TV answering on port 8001, or nil.
    func samsung(host: String) async -> TVDevice?
    /// An LG webOS TV answering on `port` (3001 secure, 3000 plain), or nil.
    func lg(host: String, port: UInt16) async -> TVDevice?
}

nonisolated struct BrandProbes: BrandProbing {
    static let samsungPort: UInt16 = 8001

    private let http: HTTPRequesting
    private let timeout: TimeInterval

    init(http: HTTPRequesting = LocalHTTPClient(), timeout: TimeInterval = 2.5) {
        self.http = http
        self.timeout = timeout
    }

    // MARK: - Samsung

    func samsung(host: String) async -> TVDevice? {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let url = URL(string: "http://\(host):\(Self.samsungPort)/api/v2/"),
              let response = try? await http.send(HTTPRequest(url: url, method: "GET", timeout: timeout)),
              (200...299).contains(response.statusCode) else {
            return nil
        }
        return Self.samsungDevice(from: response.data, host: host)
    }

    /// Reads the TV description. It must say Samsung somewhere in its name or type. Public for checking.
    static func samsungDevice(from data: Data, host: String) -> TVDevice? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let device = json["device"] as? [String: Any]
        let name = (device?["name"] as? String) ?? (json["name"] as? String)
        let model = device?["modelName"] as? String
        let said = [json["type"] as? String, device?["type"] as? String, json["name"] as? String, name]
            .compactMap { $0 }
        guard device != nil,
              said.contains(where: { TVBrand.identify(manufacturer: $0) == .samsung }) else {
            return nil
        }
        var details = [DeviceDetail(source: "Samsung TV description", key: "port", value: String(samsungPort))]
        if let name { details.append(DeviceDetail(source: "Samsung TV description", key: "name", value: name)) }
        if let model { details.append(DeviceDetail(source: "Samsung TV description", key: "modelName", value: model)) }
        return TVDevice(
            name: name,
            brand: .samsung,
            platform: .tizen,
            host: host,
            port: Int(samsungPort),
            modelName: model,
            details: details
        )
    }

    // MARK: - LG

    func lg(host: String, port: UInt16) async -> TVDevice? {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let url = URL(string: "\(port == 3001 ? "wss" : "ws")://\(host):\(port)") else {
            return nil
        }
        guard await Self.answersLikeWebOS(url: url, timeout: timeout) else { return nil }
        return TVDevice(
            brand: .lg,
            platform: .webOS,
            host: host,
            port: Int(port),
            details: [DeviceDetail(source: "LG webOS probe", key: "SSAP answered on port", value: String(port))]
        )
    }

    /// Opens the socket, asks for something without registering and checks that the reply has the shape of
    /// an SSAP answer to that same request id. Nothing is registered, so the TV shows no prompt.
    static func answersLikeWebOS(url: URL, timeout: TimeInterval) async -> Bool {
        let session = URLSession(configuration: .ephemeral, delegate: LocalTrustDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let task = session.webSocketTask(with: url)
        task.resume()
        let probeID = "probe_\(UUID().uuidString.prefix(8))"
        let request = "{\"type\":\"request\",\"id\":\"\(probeID)\",\"uri\":\"ssap://system/getSystemInfo\"}"

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                do {
                    try await task.send(.string(request))
                    let message = try await task.receive()
                    let data: Data
                    switch message {
                    case .string(let text): data = Data(text.utf8)
                    case .data(let bytes): data = bytes
                    @unknown default: return false
                    }
                    return isSSAPAnswer(data, id: probeID)
                } catch {
                    return false
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            task.cancel(with: .goingAway, reason: nil)
            return first
        }
    }

    /// An SSAP answer is JSON with our request id and a `type` of error, response or registered.
    /// Public for checking.
    static func isSSAPAnswer(_ data: Data, id: String) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["id"] as? String == id,
              let type = json["type"] as? String else {
            return false
        }
        return ["error", "response", "registered"].contains(type)
    }
}
