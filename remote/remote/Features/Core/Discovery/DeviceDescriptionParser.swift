//
//  DeviceDescriptionParser.swift
//  tvRemoteDemo
//

import Foundation

/// Collects the first non-empty text of each wanted element name.
private nonisolated final class XMLFieldCollector: NSObject, XMLParserDelegate {
    private let wanted: Set<String>
    private var buffer = ""
    private(set) var rootElement: String?
    private(set) var values: [String: String] = [:]

    init(wanted: Set<String>) {
        self.wanted = wanted
    }

    static func collect(_ data: Data, wanted: Set<String>) -> XMLFieldCollector {
        let collector = XMLFieldCollector(wanted: wanted)
        let parser = XMLParser(data: data)
        parser.delegate = collector
        _ = parser.parse()
        return collector
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if rootElement == nil {
            rootElement = elementName
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if wanted.contains(elementName), values[elementName] == nil, !text.isEmpty {
            values[elementName] = text
        }
        buffer = ""
    }
}

/// One text value of an XML document, keyed by its element path below the root element,
/// for example `device/friendlyName`. Attributes are keyed `path@name`. A path that repeats gets
/// an index from its second occurrence on, for example `serviceList/service/serviceId[1]`.
nonisolated struct XMLLeaf: Sendable, Equatable {
    var key: String
    var value: String
}

/// Collects every leaf element (one with text and no child elements) and every attribute.
private nonisolated final class XMLLeafCollector: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var hasChildElement: [Bool] = []
    private var buffer = ""
    private var occurrences: [String: Int] = [:]
    private(set) var leaves: [XMLLeaf] = []

    static func collect(_ data: Data) -> [XMLLeaf] {
        let collector = XMLLeafCollector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        _ = parser.parse()
        return collector.leaves
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if !hasChildElement.isEmpty {
            hasChildElement[hasChildElement.count - 1] = true
        }
        path.append(elementName)
        hasChildElement.append(false)
        buffer = ""

        for (name, value) in attributeDict.sorted(by: { $0.key < $1.key }) where !value.isEmpty {
            record(key: "\(belowRoot)@\(name)", value: value)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLeaf = !(hasChildElement.last ?? false)
        if isLeaf, !text.isEmpty {
            record(key: belowRoot.isEmpty ? "(root)" : belowRoot, value: text)
        }
        path.removeLast()
        hasChildElement.removeLast()
        buffer = ""
    }

    private var belowRoot: String {
        path.dropFirst().joined(separator: "/")
    }

    private func record(key: String, value: String) {
        let count = occurrences[key, default: 0]
        occurrences[key] = count + 1
        leaves.append(XMLLeaf(key: count == 0 ? key : "\(key)[\(count)]", value: value))
    }
}

/// The fields of a UPnP device description that discovery uses.
nonisolated struct DeviceDescription: Sendable, Equatable {
    var friendlyName: String?
    var manufacturer: String?
    var modelName: String?
    var udn: String?
    var deviceType: String?
    /// Every text value of the document, for the device detail screen.
    var fields: [XMLLeaf] = []
}

nonisolated enum DeviceDescriptionParser {
    /// Parses a UPnP device description (the XML behind an SSDP LOCATION header).
    /// Nested embedded devices are ignored for the named fields: the first value of each wins.
    /// Returns nil when the data is not XML or holds none of the fields.
    static func parse(_ data: Data) -> DeviceDescription? {
        let collector = XMLFieldCollector.collect(
            data,
            wanted: ["friendlyName", "manufacturer", "modelName", "UDN", "deviceType"]
        )
        let values = collector.values
        guard !values.isEmpty else { return nil }
        return DeviceDescription(
            friendlyName: values["friendlyName"],
            manufacturer: values["manufacturer"],
            modelName: values["modelName"],
            udn: values["UDN"],
            deviceType: values["deviceType"],
            fields: XMLLeafCollector.collect(data)
        )
    }
}

/// What Roku's `GET /query/device-info` tells us.
nonisolated struct RokuDeviceInfo: Sendable, Equatable {
    var name: String?
    var modelName: String?
    /// Who made the device. A TCL or Hisense Roku TV should say so here.
    var vendorName: String?
    /// Every field of the reply. It includes serial number and MAC addresses on some models.
    var fields: [XMLLeaf] = []
}

nonisolated enum RokuDeviceInfoParser {
    /// Returns nil unless the document's root element is `device-info`. That is the proof of a Roku.
    /// Element names come from memory of Roku's External Control Protocol.
    /// TODO: verify `user-device-name`, `friendly-device-name`, `model-name` and `vendor-name` against
    /// Roku's ECP docs (the docs site is blocked in the build environment).
    static func parse(_ data: Data) -> RokuDeviceInfo? {
        let collector = XMLFieldCollector.collect(
            data,
            wanted: ["user-device-name", "friendly-device-name", "model-name", "vendor-name"]
        )
        guard collector.rootElement == "device-info" else { return nil }
        let values = collector.values
        return RokuDeviceInfo(
            name: values["user-device-name"] ?? values["friendly-device-name"],
            modelName: values["model-name"],
            vendorName: values["vendor-name"],
            fields: XMLLeafCollector.collect(data)
        )
    }
}

nonisolated struct RokuApp: Sendable, Equatable {
    var id: String
    var name: String
    var version: String?
}

/// Reads Roku's `GET /query/apps` reply (endpoint listed in README.md, Roku quick reference).
nonisolated enum RokuAppsParser {
    /// Returns nil unless the root element is `apps`.
    /// TODO: verify the `<app id=... version=...>Name</app>` shape against Roku's ECP docs.
    static func parse(_ data: Data) -> [RokuApp]? {
        let collector = RokuAppsCollector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        _ = parser.parse()
        return collector.rootElement == "apps" ? collector.apps : nil
    }
}

private nonisolated final class RokuAppsCollector: NSObject, XMLParserDelegate {
    private(set) var rootElement: String?
    private(set) var apps: [RokuApp] = []
    private var currentAttributes: [String: String]?
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if rootElement == nil {
            rootElement = elementName
        }
        if elementName == "app" {
            currentAttributes = attributeDict
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentAttributes != nil {
            buffer += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        guard elementName == "app", let attributes = currentAttributes else { return }
        let name = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        apps.append(RokuApp(id: attributes["id"] ?? "?", name: name, version: attributes["version"]))
        currentAttributes = nil
        buffer = ""
    }
}
