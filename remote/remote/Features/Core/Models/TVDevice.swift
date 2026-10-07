//
//  TVDevice.swift
//  tvRemoteDemo
//

import Foundation

/// How a device was found.
nonisolated enum DiscoverySource: String, Sendable, Hashable {
    case ssdp
    case bonjour
    case portProbe
}

/// One piece of raw data read from a device, such as an SSDP header or a Roku device-info field.
nonisolated struct DeviceDetail: Hashable, Sendable {
    /// Where it came from, for example "SSDP response" or "Roku device-info".
    var source: String
    var key: String
    var value: String
}

/// A smart TV found on the local network. Devices are keyed by IPv4 `host`.
nonisolated struct TVDevice: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var brand: TVBrand
    /// The control protocol the TV speaks. It decides how the TV is paired.
    var platform: TVPlatform
    var host: String
    var port: Int?
    var modelName: String?
    var sources: Set<DiscoverySource>
    /// Known control ports that accepted a connection. An open port alone does not prove a brand.
    var openControlPorts: Set<UInt16>
    /// Every raw field we could read from the device. Shown on the detail screen and printed in
    /// debug builds. It can include serial numbers and MAC addresses, so it is never stored or sent.
    var details: [DeviceDetail]

    init(
        id: String? = nil,
        name: String? = nil,
        brand: TVBrand = .unknown,
        platform: TVPlatform = .unknown,
        host: String,
        port: Int? = nil,
        modelName: String? = nil,
        sources: Set<DiscoverySource> = [],
        openControlPorts: Set<UInt16> = [],
        details: [DeviceDetail] = []
    ) {
        self.id = id ?? host
        self.name = name ?? host
        self.brand = brand
        self.platform = platform
        self.host = host
        self.port = port
        self.modelName = modelName
        self.sources = sources
        self.openControlPorts = openControlPorts
        self.details = details
    }

    /// Combines two sightings of the same host. The more specific brand wins (see
    /// `TVBrand.specificity`), a known platform beats an unknown one, a real name beats the bare IP
    /// address, and sources, ports and details are unioned.
    func merging(_ other: TVDevice) -> TVDevice {
        var merged = self
        if other.brand.specificity > merged.brand.specificity {
            merged.brand = other.brand
        }
        if merged.platform == .unknown || (merged.platform == .bravia && other.platform == .androidTV) {
            // A Sony that also speaks the Android TV remote is controlled that way: it needs no TV settings.
            merged.platform = other.platform
        }
        if merged.id == merged.host {
            merged.id = other.id
        }
        if merged.name == merged.host || merged.name.isEmpty {
            merged.name = other.name
        }
        merged.port = merged.port ?? other.port
        merged.modelName = merged.modelName ?? other.modelName
        merged.sources.formUnion(other.sources)
        merged.openControlPorts.formUnion(other.openControlPorts)
        for detail in other.details where !merged.details.contains(detail) {
            merged.details.append(detail)
        }
        return merged
    }

    /// "Brand · IP · model · what pairing needs" for list rows. When the maker is not known or not
    /// listed but the control protocol is (an Android / Google TV found by Bonjour), the protocol's
    /// name is shown instead. Otherwise `.unknown` shows as "Unidentified".
    var summaryLine: String {
        let brandText: String
        if (brand == .unknown || brand == .other) && platform != .unknown {
            brandText = platform.displayName
        } else {
            brandText = brand == .unknown ? "Unidentified" : brand.displayName
        }
        return [brandText, host, modelName, platform.pairingKind.shortDescription]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// Everything we know about the device as readable text: the parsed fields first, then the raw
    /// details grouped by source.
    var debugReport: String {
        var lines = [
            "TV device: \(name)",
            "  brand: \(brand.displayName)",
            "  platform: \(platform.displayName)",
            "  host: \(host)"
        ]
        if let port { lines.append("  port: \(port)") }
        if let modelName { lines.append("  model: \(modelName)") }
        lines.append("  id: \(id)")
        lines.append("  found by: \(sources.map(\.rawValue).sorted().joined(separator: ", "))")
        if !openControlPorts.isEmpty {
            lines.append("  open control ports: \(openControlPorts.sorted().map(String.init).joined(separator: ", "))")
        }

        var sourceOrder: [String] = []
        var detailsBySource: [String: [DeviceDetail]] = [:]
        for detail in details {
            if detailsBySource[detail.source] == nil {
                sourceOrder.append(detail.source)
            }
            detailsBySource[detail.source, default: []].append(detail)
        }
        for source in sourceOrder {
            lines.append("")
            lines.append("[\(source)]")
            for detail in detailsBySource[source] ?? [] {
                lines.append("  \(detail.key): \(detail.value)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
