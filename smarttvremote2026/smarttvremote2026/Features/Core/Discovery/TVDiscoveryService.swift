//
//  TVDiscoveryService.swift
//  tvRemoteDemo
//

import Foundation

/// Finds smart TVs on the local Wi-Fi network and streams them as they are found.
///
/// Four methods run together:
/// 1. SSDP by multicast. It needs Apple's multicast entitlement and quietly fails without it.
/// 2. SSDP by unicast: the same search sent to each address of the local subnet, which needs no
///    entitlement. This is what finds Samsung, LG, Sony, Vizio, Roku and other TVs on an iPhone.
/// 3. Bonjour, through `NWBrowser`.
/// 4. The subnet sweep of the control ports that have a brand check: Roku, Samsung and LG. It runs
///    in parallel with the rest, and when the caller picked one of those brands it goes first.
///
/// Only TVs are reported. A device is emitted once its brand is known:
/// - a Roku must answer `/query/device-info`;
/// - any other brand must be identified by its SSDP description or Bonjour service type, and its
///   SSDP response must advertise a TV/media service.
/// Apple devices are never reported, and an open port alone never creates a device.
///
/// Nothing starts until `discover` is called.
nonisolated final class TVDiscoveryService: Sendable {
    /// Search targets for the SSDP M-SEARCH.
    /// TODO: verify `roku:ecp` against Roku's ECP docs; the DIAL and MediaRenderer types are
    /// UPnP/DIAL standard names, which most smart TVs answer.
    static let searchTargets = [
        "ssdp:all",
        "roku:ecp",
        "urn:dial-multiscreen-org:service:dial:1",
        "urn:schemas-upnp-org:device:MediaRenderer:1"
    ]

    /// `searchTargets`, with the target only `brand` answers (if we know one) first.
    static func orderedSearchTargets(preferring brand: TVBrand?) -> [String] {
        guard let brand, let own = TVBrand.ssdpSearchTargetTable[brand] else { return searchTargets }
        return [own] + searchTargets.filter { $0 != own }
    }

    /// A search response counts as a TV only when it names one of these.
    private static let tvServiceMarkers = ["dial-multiscreen-org", "mediarenderer", "roku:ecp"]

    private let ssdp: SSDPTransport
    private let http: HTTPDataFetching
    private let bonjour: BonjourBrowsing
    private let portProber: PortProbing
    private let brandProbes: BrandProbing
    private let subnetProvider: LocalSubnetProviding
    private let configuration: TVDiscoveryConfiguration

    init(
        ssdp: SSDPTransport = CombinedSSDPTransport(),
        http: HTTPDataFetching = URLSessionDataFetcher(),
        bonjour: BonjourBrowsing = NWBonjourBrowser(),
        portProber: PortProbing = NWPortProber(),
        brandProbes: BrandProbing = BrandProbes(),
        subnetProvider: LocalSubnetProviding = InterfaceSubnetProvider(),
        configuration: TVDiscoveryConfiguration = TVDiscoveryConfiguration()
    ) {
        self.ssdp = ssdp
        self.http = http
        self.bonjour = bonjour
        self.portProber = portProber
        self.brandProbes = brandProbes
        self.subnetProvider = subnetProvider
        self.configuration = configuration
    }

    /// Starts a scan. A device is yielded when first seen and again when a later sighting adds
    /// to it. The stream ends after `timeout` seconds. Breaking out of the `for await` loop stops
    /// the scan.
    ///
    /// `preferredBrand` is the brand the user picked. It changes how the scan runs, not what
    /// counts as a TV: that brand's checks run first, and its verified-port sweep starts at once.
    func discover(timeout: TimeInterval = 10, preferredBrand: TVBrand? = nil) -> AsyncStream<TVDevice> {
        AsyncStream<TVDevice> { continuation in
            let merger = DeviceMerger(continuation: continuation)

            let scan = Task {
                await self.runSources(merger, preferredBrand: preferredBrand)
                continuation.finish()
            }
            // The deadline finishes the stream itself, so a source that ignores cancellation
            // cannot keep the stream open.
            let deadline = Task {
                try? await ThreadManager.delay(seconds: max(timeout, 0))
                continuation.finish()
                scan.cancel()
            }
            continuation.onTermination = { _ in
                scan.cancel()
                deadline.cancel()
            }
        }
    }

    // MARK: - Sources

    private func runSources(_ merger: DeviceMerger, preferredBrand: TVBrand?) async {
        let ports = ControlPorts.verifiedPorts(preferring: preferredBrand)
        let brandLabel = preferredBrand?.displayName ?? "none"
        await LoggerManager.debug("Discovery started, preferredBrand: \(brandLabel)", category: "Discovery")

        // All three run at once. The sweep is no longer only a fallback: a TV that does not answer an SSDP
        // search (or whose answer names no brand) is still found by its own control port.
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.runSSDP(merger, preferredBrand: preferredBrand) }
            group.addTask { await self.runBonjour(merger, preferredBrand: preferredBrand) }
            if !ports.isEmpty {
                group.addTask { await self.sweepSubnet(ports: ports, merger) }
            }
        }
    }

    private func runSSDP(_ merger: DeviceMerger, preferredBrand: TVBrand?) async {
        let targets = Self.orderedSearchTargets(preferring: preferredBrand)
        let responses = ssdp.search(searchTargets: targets, window: configuration.ssdpWindow)

        await withTaskGroup(of: Bool.self) { group in
            do {
                for try await datagram in responses {
                    group.addTask { await self.handleSSDP(datagram, merger) }
                }
            } catch {
                // TVDiscoveryError.ssdpUnavailable or a socket error: the other sources carry on.
                LoggerManager.debug("SSDP stream ended with error: \(error)", category: "Discovery")
            }
            for await _ in group {}
        }
    }

    private func runBonjour(_ merger: DeviceMerger, preferredBrand: TVBrand?) async {
        let types = TVBrand.orderedBonjourServiceTypes(preferring: preferredBrand)
        for await service in bonjour.browse(serviceTypes: types) {
            guard let host = service.host, IPv4.isPrivateOrLinkLocal(host) else { continue }
            // The service type must name a platform. Anything else is not reported as a TV. The
            // brand is the platform's maker when only one uses it, otherwise "Other" until another
            // sighting (SSDP) names the maker.
            let platform = TVPlatform.identify(bonjourServiceType: service.serviceType)
            guard platform != .unknown else { continue }

            await merger.add(TVDevice(
                name: service.name,
                brand: platform.impliedBrand ?? .other,
                platform: platform,
                host: host,
                port: service.port,
                sources: [.bonjour],
                details: Self.bonjourDetails(service)
            ))
        }
    }

    // MARK: - SSDP

    /// Returns true when the response produced a TV.
    private func handleSSDP(_ datagram: SSDPDatagram, _ merger: DeviceMerger) async -> Bool {
        // The address the datagram really came from is the device address. The LOCATION header
        // is only fetched when it also points at the local network.
        guard IPv4.isPrivateOrLinkLocal(datagram.sourceHost),
              let response = SSDPResponseParser.parse(datagram.text) else { return false }
        let host = datagram.sourceHost

        var description: DeviceDescription?
        if let location = response.location {
            // Every search target of one TV returns the same LOCATION. Fetch it once.
            guard await merger.claimLocation(location) else { return false }
            if let locationHost = location.host, IPv4.isPrivateOrLinkLocal(locationHost),
               let data = try? await http.data(from: location, timeout: configuration.fetchTimeout) {
                description = DeviceDescriptionParser.parse(data)
            }
        }

        if TVBrand.isExcluded(
            manufacturer: description?.manufacturer,
            modelName: description?.modelName,
            serverHeader: response.server
        ) {
            await merger.block(host: host)
            return false
        }

        let brand = TVBrand.identify(
            manufacturer: description?.manufacturer,
            modelName: description?.modelName,
            serverHeader: response.server
        )
        // Routers, printers, speakers and phones also answer `ssdp:all`. A TV has a known brand
        // and advertises a TV/media service.
        guard brand != .unknown, advertisesTVService(response, description) else { return false }

        let platform = TVPlatform.inferred(from: brand)
        var device = TVDevice(
            id: description?.udn,
            name: description?.friendlyName,
            brand: brand,
            platform: platform,
            host: host,
            port: response.location?.port,
            modelName: description?.modelName,
            sources: [.ssdp],
            details: Self.ssdpDetails(response, description)
        )

        if brand == .roku {
            // A Roku has to prove itself. Without a device-info answer (for example when its
            // network control setting is off) we cannot control it, so it is not listed.
            guard let roku = await fetchRokuDevice(host: host) else { return false }
            device = device.merging(roku)
        } else if platform == .unknown, let roku = await fetchRokuDevice(host: host) {
            // TCL, Hisense and others also build Roku TVs. If it answers like a Roku, it is one.
            device = device.merging(roku)
        }

        await merger.add(device)
        return true
    }

    private func advertisesTVService(_ response: SSDPResponse, _ description: DeviceDescription?) -> Bool {
        let text = [response.searchTarget, response.usn, description?.deviceType]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return Self.tvServiceMarkers.contains { text.contains($0) }
    }

    private static func ssdpDetails(_ response: SSDPResponse, _ description: DeviceDescription?) -> [DeviceDetail] {
        let headers = response.headers.sorted { $0.key < $1.key }
            .map { DeviceDetail(source: "SSDP response", key: $0.key, value: $0.value) }
        let fields = (description?.fields ?? [])
            .map { DeviceDetail(source: "UPnP description", key: $0.key, value: $0.value) }
        return headers + fields
    }

    private static func bonjourDetails(_ service: BonjourService) -> [DeviceDetail] {
        var details = [
            DeviceDetail(source: "Bonjour", key: "service name", value: service.name),
            DeviceDetail(source: "Bonjour", key: "service type", value: service.serviceType)
        ]
        if let port = service.port {
            details.append(DeviceDetail(source: "Bonjour", key: "port", value: String(port)))
        }
        details += service.txt.sorted { $0.key < $1.key }
            .map { DeviceDetail(source: "Bonjour TXT record", key: $0.key, value: $0.value) }
        return details
    }

    // MARK: - Subnet sweep

    /// Probes every host of the local subnet, one port after the other (the first port across all
    /// hosts, then the next), so the first port shows results early.
    private func sweepSubnet(ports: [UInt16], _ merger: DeviceMerger) async {
        guard let subnet = subnetProvider.currentSubnet() else { return }
        let hosts = SubnetHosts.hosts(in: subnet)
        let targets = ports.flatMap { port in hosts.map { ProbeTarget(host: $0, port: port) } }

        await forEachConcurrently(targets, limit: configuration.maxConcurrentProbes) { target in
            await self.probe(host: target.host, port: target.port, merger)
        }
    }

    private func probe(host: String, port: UInt16, _ merger: DeviceMerger) async {
        guard await portProber.isOpen(host: host, port: port, timeout: configuration.probeTimeout),
              !Task.isCancelled else { return }

        // An open port alone never makes a TV. Only a port whose owner can prove the brand counts:
        // Roku by its device-info reply, Samsung by its TV description, LG by an SSAP error reply. A host
        // that answers none of them (a router login page, a dev server) is ignored.
        let found: TVDevice?
        switch port {
        case ControlPorts.rokuECP: found = await fetchRokuDevice(host: host)
        case BrandProbes.samsungPort: found = await brandProbes.samsung(host: host)
        case 3000, 3001: found = await brandProbes.lg(host: host, port: port)
        default: found = nil
        }
        guard var device = found, !Task.isCancelled else { return }
        device.sources = [.portProbe]
        device.openControlPorts = [port]
        device.details.append(DeviceDetail(source: "Port probe", key: "open port", value: String(port)))
        await merger.add(device)
    }

    /// Reads a Roku's `GET /query/device-info` (proof that it is a Roku) and `GET /query/apps`
    /// (both listed in README.md, Roku quick reference). Returns nil if it does not answer like a Roku.
    private func fetchRokuDevice(host: String) async -> TVDevice? {
        guard let infoURL = rokuURL(host: host, path: "query/device-info"),
              let infoData = try? await http.data(from: infoURL, timeout: configuration.fetchTimeout),
              let info = RokuDeviceInfoParser.parse(infoData) else { return nil }

        var details = info.fields.map { DeviceDetail(source: "Roku device-info", key: $0.key, value: $0.value) }

        if let appsURL = rokuURL(host: host, path: "query/apps"),
           let appsData = try? await http.data(from: appsURL, timeout: configuration.fetchTimeout),
           let apps = RokuAppsParser.parse(appsData) {
            details += apps.map { app in
                let version = app.version.map { " v\($0)" } ?? ""
                return DeviceDetail(source: "Roku apps", key: app.id, value: app.name + version)
            }
        }

        // The maker's name refines the label: a TCL Roku TV should say TCL, not just Roku.
        let vendorBrand = TVBrand.identify(manufacturer: info.vendorName)

        return TVDevice(
            name: info.name,
            brand: vendorBrand == .unknown ? .roku : vendorBrand,
            platform: .roku,
            host: host,
            port: Int(ControlPorts.rokuECP),
            modelName: info.modelName,
            details: details
        )
    }

    private func rokuURL(host: String, path: String) -> URL? {
        URL(string: "http://\(host):\(ControlPorts.rokuECP)/\(path)")
    }

    // MARK: - Helpers

    private nonisolated struct ProbeTarget: Sendable {
        var host: String
        var port: UInt16
    }

    /// Runs `body` for every item with at most `limit` running at once.
    private func forEachConcurrently<Item: Sendable>(
        _ items: [Item],
        limit: Int,
        _ body: @escaping @Sendable (Item) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = items.makeIterator()
            for _ in 0..<max(limit, 1) {
                guard let item = iterator.next() else { break }
                group.addTask { await body(item) }
            }
            while await group.next() != nil {
                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }
                if let item = iterator.next() {
                    group.addTask { await body(item) }
                }
            }
        }
    }
}

/// Merges sightings of the same host and yields a device when it is new or improved. A device
/// whose brand is still unknown is remembered but never yielded, so only identified TVs reach
/// the stream. Yielding happens inside the actor, so updates for one host arrive in order.
private actor DeviceMerger {
    private let continuation: AsyncStream<TVDevice>.Continuation
    private var devices: [String: TVDevice] = [:]
    private var blockedHosts: Set<String> = []
    private var claimedLocations: Set<URL> = []

    init(continuation: AsyncStream<TVDevice>.Continuation) {
        self.continuation = continuation
    }

    func add(_ device: TVDevice) {
        guard !blockedHosts.contains(device.host) else { return }
        let existing = devices[device.host]
        let merged = existing.map { $0.merging(device) } ?? device
        guard merged != existing else { return }
        devices[device.host] = merged
        guard merged.brand != .unknown else { return }
        let sources = merged.sources.map(\.rawValue).sorted().joined(separator: ", ")
        LoggerManager.debug(
            "TV found host=\(merged.host) brand=\(merged.brand.displayName) platform=\(merged.platform.displayName) sources=[\(sources)]",
            category: "Discovery"
        )
        continuation.yield(merged)
    }

    /// Never report this host again (used for devices that must be excluded, such as Apple TV).
    func block(host: String) {
        blockedHosts.insert(host)
        devices[host] = nil
    }

    /// True the first time a LOCATION URL is claimed.
    func claimLocation(_ location: URL) -> Bool {
        claimedLocations.insert(location).inserted
    }
}
