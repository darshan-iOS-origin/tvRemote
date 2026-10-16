//
//  SSDPResponseParser.swift
//  tvRemoteDemo
//

import Foundation

/// A parsed SSDP search response.
nonisolated struct SSDPResponse: Sendable, Equatable {
    var location: URL?
    var server: String?
    var searchTarget: String?
    var usn: String?
    /// Every header of the response, with lower-case names.
    var headers: [String: String] = [:]
}

nonisolated enum SSDPResponseParser {
    /// Parses one datagram. Returns nil for anything that is not a `200 OK` search response
    /// (NOTIFY packets, garbage, empty text) or that carries neither LOCATION nor USN.
    static func parse(_ text: String) -> SSDPResponse? {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let statusLine = lines.first, isOKStatus(statusLine) else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, headers[name] == nil {
                headers[name] = value
            }
        }

        let location = headers["location"].flatMap(URL.init(string:))
        guard location != nil || headers["usn"] != nil else { return nil }

        return SSDPResponse(
            location: location,
            server: headers["server"],
            searchTarget: headers["st"],
            usn: headers["usn"],
            headers: headers
        )
    }

    private static func isOKStatus(_ line: String) -> Bool {
        let parts = line.split(separator: " ")
        return parts.count >= 2 && parts[0].uppercased().hasPrefix("HTTP/1.") && parts[1] == "200"
    }
}
