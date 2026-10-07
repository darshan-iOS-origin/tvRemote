//
//  DLNAMessages.swift
//  tvRemoteDemo
//
//  The UPnP AV messages that make a TV play a web address: SOAP `SetAVTransportURI` with DIDL-Lite
//  metadata, then `Play`, `Pause` and `Stop` on the TV's AVTransport service. The shapes follow the
//  UPnP AVTransport:1 service and DIDL-Lite schema, and the field set that DLNA controllers send.
//  UNVERIFIED on a real TV: which fields a given Samsung or LG renderer insists on.
//

import Foundation

nonisolated enum DLNAMessages {
    static let serviceType = "urn:schemas-upnp-org:service:AVTransport:1"

    /// What to put in the `SOAPACTION` header for an action.
    static func soapAction(_ action: String) -> String {
        "\"\(serviceType)#\(action)\""
    }

    /// The text of an XML element or attribute, with the five special characters escaped.
    static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.append(character)
            }
        }
        return result
    }

    /// The UPnP class of an item, from its content type.
    static func upnpClass(for contentType: String) -> String {
        if contentType.hasPrefix("image/") { return "object.item.imageItem.photo" }
        if contentType.hasPrefix("audio/") { return "object.item.audioItem.musicTrack" }
        return "object.item.videoItem"
    }

    /// DIDL-Lite metadata for one item: its title, class and the address with its `protocolInfo`.
    static func didl(url: String, contentType: String, title: String) -> String {
        "<DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\" "
            + "xmlns:dc=\"http://purl.org/dc/elements/1.1/\" "
            + "xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\">"
            + "<item id=\"0\" parentID=\"-1\" restricted=\"1\">"
            + "<dc:title>\(escape(title))</dc:title>"
            + "<upnp:class>\(upnpClass(for: contentType))</upnp:class>"
            + "<res protocolInfo=\"http-get:*:\(escape(contentType)):*\">\(escape(url))</res>"
            + "</item></DIDL-Lite>"
    }

    /// A SOAP request body for one action. Argument values are escaped here.
    static func envelope(action: String, arguments: [(name: String, value: String)]) -> Data {
        let body = arguments.map { "<\($0.name)>\(escape($0.value))</\($0.name)>" }.joined()
        let text = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" "
            + "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
            + "<s:Body><u:\(action) xmlns:u=\"\(serviceType)\">\(body)</u:\(action)></s:Body></s:Envelope>"
        return Data(text.utf8)
    }

    static func setURI(url: String, contentType: String, title: String) -> Data {
        envelope(action: "SetAVTransportURI", arguments: [
            ("InstanceID", "0"),
            ("CurrentURI", url),
            ("CurrentURIMetaData", didl(url: url, contentType: contentType, title: title))
        ])
    }

    static func play() -> Data {
        envelope(action: "Play", arguments: [("InstanceID", "0"), ("Speed", "1")])
    }

    static func pause() -> Data {
        envelope(action: "Pause", arguments: [("InstanceID", "0")])
    }

    static func stop() -> Data {
        envelope(action: "Stop", arguments: [("InstanceID", "0")])
    }
}
