//
//  BraviaMessages.swift
//  tvRemoteDemo
//
//  The messages of Sony Bravia IP control, as the open-source libraries pybravia (MIT), sony_bravia_psk (MIT)
//  and bravia-auth-and-remote (ISC) send them. Only the shapes are used, no code. UNVERIFIED on a real TV.
//    - JSON-RPC over HTTP: `POST http://<ip>/sony/<service>` with {"method", "params", "id", "version"}.
//    - PIN sign-in: `actRegister` on `accessControl`. The first call makes the TV show a PIN (answer 401).
//      The second sends `Authorization: Basic base64(":" + PIN)` and the TV answers with an `auth` cookie.
//    - Keys: SOAP `X_SendIRCC` on `/sony/IRCC`, with a code taken from the TV's own list.
//

import Foundation

nonisolated enum BraviaMessages {
    /// The name this app gives itself on the TV's list of paired devices.
    static let nickname = "TV Remote"

    // MARK: - JSON-RPC

    /// The body of one JSON-RPC call.
    static func rpc(method: String, params: [Any] = [], id: Int = 1) -> Data? {
        let body: [String: Any] = ["method": method, "params": params, "id": id, "version": "1.0"]
        return try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    /// The `actRegister` call. The `WOL` entry asks the TV to allow waking it later.
    static func actRegister(clientID: String) -> Data? {
        let client: [String: Any] = ["clientid": clientID, "nickname": nickname, "level": "private"]
        let functions: [[String: Any]] = [["value": "yes", "function": "WOL"]]
        return rpc(method: "actRegister", params: [client, functions], id: 8)
    }

    /// `Authorization: Basic ...` for the PIN: an empty user name and the PIN as the password.
    static func basicAuthorization(pin: String) -> String {
        "Basic " + Data(":\(pin)".utf8).base64EncodedString()
    }

    /// The value of the `auth` cookie in a `Set-Cookie` header, nil if there is none. The header can hold
    /// several cookies joined into one string, so only the `auth=` part is read.
    static func authCookie(fromSetCookie header: String?) -> String? {
        guard let header, let range = header.range(of: "auth=") else { return nil }
        let rest = header[range.upperBound...]
        let value = rest.prefix { $0 != ";" && $0 != "," && !$0.isWhitespace }
        return value.isEmpty ? nil : String(value)
    }

    // MARK: - IRCC (keys)

    static let irccAction = "\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\""

    /// The SOAP body that sends one remote-control code.
    static func irccEnvelope(code: String) -> Data {
        let text = "<?xml version=\"1.0\"?>"
            + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" "
            + "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
            + "<s:Body><u:X_SendIRCC xmlns:u=\"urn:schemas-sony-com:service:IRCC:1\">"
            + "<IRCCCode>\(DLNAMessages.escape(code))</IRCCCode></u:X_SendIRCC></s:Body></s:Envelope>"
        return Data(text.utf8)
    }

    /// Reads the TV's code list from a `getRemoteControllerInfo` answer: `result[1]` is a list of
    /// `{name, value}`. Public for checking.
    static func irccCodes(from data: Data) -> [String: String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [Any],
              result.count > 1,
              let items = result[1] as? [[String: Any]] else {
            return [:]
        }
        var codes: [String: String] = [:]
        for item in items {
            if let name = item["name"] as? String, let value = item["value"] as? String {
                codes[name] = value
            }
        }
        return codes
    }
}
