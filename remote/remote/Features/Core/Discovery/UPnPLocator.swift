//
//  UPnPLocator.swift
//  tvRemoteDemo
//
//  Finds where a TV's UPnP AVTransport service listens, so the TV can be told to play a web address
//  (DLNA). It sends an SSDP `M-SEARCH` straight to the TV on UDP 1900. A unicast packet to the TV's own
//  address needs no multicast entitlement, unlike discovery's broadcast. Each answer's `LOCATION` is a
//  device description document, which names the AVTransport service's control address.
//
//  Safety: only the TV's own (private) address is searched, and a description is only fetched from that
//  same address. UNVERIFIED on a real TV: that Samsung and LG answer a unicast M-SEARCH.
//

import Foundation

nonisolated struct UPnPLocator: Sendable {
    private static let searchTargets = ["urn:schemas-upnp-org:device:MediaRenderer:1", "ssdp:all"]
    private static let listenSeconds = 2.0

    private let http: HTTPRequesting

    init(http: HTTPRequesting = LocalHTTPClient()) {
        self.http = http
    }

    /// The AVTransport control address of the TV at `host`, or nil if none was found.
    func avTransportControlURL(host: String) async -> URL? {
        guard LocalTrustPolicy.shouldTrust(host: host) else { return nil }
        let locations = await withCheckedContinuation { (continuation: CheckedContinuation<[URL], Never>) in
            ThreadManager.backgroundQueue.async {
                continuation.resume(returning: Self.search(host: host))
            }
        }
        for location in locations {
            // Only a description served by the TV itself is read.
            guard location.host == host,
                  let response = try? await http.send(HTTPRequest(url: location, method: "GET", timeout: 4)),
                  (200...299).contains(response.statusCode),
                  let control = UPnPDescription.avTransportControlURL(in: response.data, location: location) else {
                continue
            }
            return control
        }
        return nil
    }

    /// Sends the searches and collects the distinct `LOCATION` addresses that come back.
    private static func search(host: String) -> [URL] {
        let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        guard descriptor >= 0 else { return [] }
        defer { close(descriptor) }

        var readTimeout = timeval(tv_sec: 0, tv_usec: 250_000)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.size))

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(1900).bigEndian
        destination.sin_addr.s_addr = inet_addr(host)

        for target in searchTargets {
            let request = Data([
                "M-SEARCH * HTTP/1.1",
                "HOST: \(host):1900",
                "MAN: \"ssdp:discover\"",
                "MX: 1",
                "ST: \(target)",
                "", ""
            ].joined(separator: "\r\n").utf8)
            _ = request.withUnsafeBytes { bytes in
                withUnsafePointer(to: &destination) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                        sendto(descriptor, bytes.baseAddress, bytes.count, 0, address,
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }

        var found: [URL] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        let deadline = Date().addingTimeInterval(listenSeconds)
        while Date() < deadline {
            let count = buffer.withUnsafeMutableBytes { raw in
                recv(descriptor, raw.baseAddress, raw.count, 0)
            }
            if count > 0 {
                let text = String(decoding: buffer[0..<count], as: UTF8.self)
                if let location = SSDPResponseParser.parse(text)?.location, !found.contains(location) {
                    found.append(location)
                }
            } else if count < 0, errno != EAGAIN, errno != EWOULDBLOCK, errno != EINTR {
                break
            }
        }
        return found
    }
}

/// Reads a UPnP device description for its AVTransport service.
nonisolated enum UPnPDescription {
    /// The control address of the first AVTransport service, made absolute against `location`.
    static func avTransportControlURL(in data: Data, location: URL) -> URL? {
        let collector = ServiceCollector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        _ = parser.parse()
        guard let service = collector.services.first(where: { $0.type.hasPrefix("urn:schemas-upnp-org:service:AVTransport:") }),
              !service.controlURL.isEmpty,
              let url = URL(string: service.controlURL, relativeTo: collector.urlBase.flatMap(URL.init(string:)) ?? location)?.absoluteURL else {
            return nil
        }
        return url
    }
}

private nonisolated final class ServiceCollector: NSObject, XMLParserDelegate {
    struct Service {
        var type = ""
        var controlURL = ""
    }

    private(set) var services: [Service] = []
    private(set) var urlBase: String?
    private var current: Service?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        text = ""
        if elementName == "service" {
            current = Service()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "serviceType": current?.type = value
        case "controlURL": current?.controlURL = value
        case "URLBase": urlBase = value.isEmpty ? nil : value
        case "service":
            if let finished = current { services.append(finished) }
            current = nil
        default: break
        }
    }
}
