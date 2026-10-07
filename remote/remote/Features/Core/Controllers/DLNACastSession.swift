//
//  DLNACastSession.swift
//  tvRemoteDemo
//
//  Casts to a Samsung or LG TV through its UPnP / DLNA media renderer: SOAP `SetAVTransportURI` with
//  the web address and DIDL-Lite metadata, then `Play`. Messages: see DLNAMessages.swift. The TV
//  downloads the file from the phone's web server, as with Google Cast.
//
//  UNVERIFIED on a real TV, the whole flow. Community reports say some newer Samsung TVs and smart
//  monitors do not accept DLNA casting at all. File names and addresses are never logged.
//

import Foundation

actor DLNACastSession: CastSession {
    private let host: String
    private let fallbackControlURL: String?
    private let locator: UPnPLocator
    private let http: HTTPRequesting

    private var controlURL: URL?

    /// - Parameter fallbackControlURL: tried when the TV does not answer the search. Samsung's renderer
    ///   is reported at `http://<ip>:9197/upnp/control/AVTransport1` (a third-party source), UNVERIFIED.
    init(host: String, fallbackControlURL: String? = nil, http: HTTPRequesting = LocalHTTPClient()) {
        self.host = host
        self.fallbackControlURL = fallbackControlURL
        self.http = http
        self.locator = UPnPLocator(http: http)
    }

    /// Finds the renderer. Throws `TVError.castFailed` when there is none.
    func open() async throws {
        if let found = await locator.avTransportControlURL(host: host) {
            controlURL = found
        } else if let fallbackControlURL, let url = URL(string: fallbackControlURL), url.host == host {
            controlURL = url
        } else {
            LoggerManager.warning("DLNA: no media renderer found", category: "Cast")
            throw TVError.castFailed
        }
    }

    func play(url: URL, contentType: String, title: String) async throws {
        // Some renderers refuse a new address while another is loaded. A failed stop is not a problem.
        _ = try? await soap("Stop", DLNAMessages.stop())
        try await soap("SetAVTransportURI", DLNAMessages.setURI(url: url.absoluteString, contentType: contentType, title: title))
        // The TV may need a moment to load the address before it accepts Play.
        var lastError: Error = TVError.castFailed
        for attempt in 0..<4 {
            try? await Task.sleep(nanoseconds: attempt == 0 ? 500_000_000 : 800_000_000)
            do {
                try await soap("Play", DLNAMessages.play())
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func pause() async throws {
        try await soap("Pause", DLNAMessages.pause())
    }

    func resume() async throws {
        try await soap("Play", DLNAMessages.play())
    }

    func stop() async throws {
        try await soap("Stop", DLNAMessages.stop())
    }

    func close() async {
        _ = try? await soap("Stop", DLNAMessages.stop())
    }

    private func soap(_ action: String, _ body: Data) async throws {
        guard let controlURL, LocalTrustPolicy.shouldTrust(host: controlURL.host ?? "") else {
            throw TVError.castFailed
        }
        let request = HTTPRequest(
            url: controlURL,
            method: "POST",
            headers: [
                "Content-Type": "text/xml; charset=\"utf-8\"",
                "SOAPACTION": DLNAMessages.soapAction(action)
            ],
            body: body,
            timeout: 8
        )
        let response: HTTPResponse
        do {
            response = try await http.send(request)
        } catch {
            throw ApprovalWait.tvError(from: error)
        }
        guard (200...299).contains(response.statusCode) else {
            LoggerManager.warning("DLNA: \(action) answered \(response.statusCode)", category: "Cast")
            throw TVError.castFailed
        }
    }
}
