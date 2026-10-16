//
//  URLSessionDataFetcher.swift
//  tvRemoteDemo
//

import Foundation

/// Plain HTTP GET on the local network. ATS allows it through `NSAllowsLocalNetworking`.
nonisolated struct URLSessionDataFetcher: HTTPDataFetching {
    /// Descriptions and device-info documents are small. Anything bigger is not from a TV.
    private static let maximumByteCount = 1_000_000

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= Self.maximumByteCount else {
            throw TVDiscoveryError.badResponse
        }
        return data
    }
}
