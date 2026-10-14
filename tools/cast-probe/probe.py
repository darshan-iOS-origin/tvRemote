#!/usr/bin/env python3
"""
Shows what a Chromecast / Google TV / Android TV on your own network is running, so you can see how another
screen-mirroring app talks to it (which Cast receiver app it launches, which namespaces it uses, and how the
video is served). It only reads: it never launches, stops or changes anything on the TV.

    python3 probe.py <tv-ip>           # then start mirroring from the other app on your phone

Prints a line whenever the running app changes: app ID, name, the namespaces the receiver listens on, and,
if a media session exists, the stream's content type, stream type and address (the part before the query).
Standard library only. Port 8009 (Cast v2, TLS, no certificate check: the TV uses a device certificate).
"""
import json
import socket
import ssl
import struct
import sys
import time

PORT = 8009
SENDER = "sender-probe"
PLATFORM = "receiver-0"
NS_CONNECTION = "urn:x-cast:com.google.cast.tp.connection"
NS_HEARTBEAT = "urn:x-cast:com.google.cast.tp.heartbeat"
NS_RECEIVER = "urn:x-cast:com.google.cast.receiver"
NS_MEDIA = "urn:x-cast:com.google.cast.media"


def varint(value):
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def field_varint(number, value):
    return varint(number << 3) + varint(value)


def field_string(number, text):
    raw = text.encode()
    return varint(number << 3 | 2) + varint(len(raw)) + raw


def frame(destination, namespace, payload):
    body = (field_varint(1, 0) + field_string(2, SENDER) + field_string(3, destination)
            + field_string(4, namespace) + field_varint(5, 0) + field_string(6, json.dumps(payload)))
    return struct.pack(">I", len(body)) + body


def read_varint(data, pos):
    shift = result = 0
    while True:
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, pos
        shift += 7


def parse(data):
    """The fields of a CastMessage that matter here: source, destination, namespace, payload."""
    fields, pos = {}, 0
    while pos < len(data):
        key, pos = read_varint(data, pos)
        number, kind = key >> 3, key & 7
        if kind == 0:
            _, pos = read_varint(data, pos)
        elif kind == 2:
            length, pos = read_varint(data, pos)
            fields[number] = data[pos:pos + length].decode(errors="replace")
            pos += length
        else:
            break
    return {"source": fields.get(2, ""), "destination": fields.get(3, ""),
            "namespace": fields.get(4, ""), "payload": fields.get(6, "")}


class Probe:
    def __init__(self, host):
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        raw = socket.create_connection((host, PORT), timeout=10)
        self.sock = context.wrap_socket(raw)
        self.sock.settimeout(1.0)
        self.buffer = b""
        self.request = 0
        self.connected_to = set()

    def send(self, destination, namespace, payload):
        self.sock.sendall(frame(destination, namespace, payload))

    def next_id(self):
        self.request += 1
        return self.request

    def connect_to(self, destination):
        if destination not in self.connected_to:
            self.connected_to.add(destination)
            self.send(destination, NS_CONNECTION, {"type": "CONNECT"})

    def read(self):
        try:
            chunk = self.sock.recv(65536)
        except socket.timeout:
            chunk = b""
        if chunk == b"" and self.buffer == b"":
            return []
        self.buffer += chunk
        messages = []
        while len(self.buffer) >= 4:
            (length,) = struct.unpack(">I", self.buffer[:4])
            if len(self.buffer) < 4 + length:
                break
            messages.append(parse(self.buffer[4:4 + length]))
            self.buffer = self.buffer[4 + length:]
        return messages


def describe_app(app):
    print("-" * 60)
    print("app id      :", app.get("appId"))
    print("name        :", app.get("displayName"))
    print("status text :", app.get("statusText"))
    print("idle screen :", app.get("isIdleScreen"))
    print("transport   :", app.get("transportId"))
    print("namespaces  :")
    for namespace in app.get("namespaces", []):
        print("   ", namespace.get("name"))


def describe_media(status):
    media = status.get("media") or {}
    content = media.get("contentId") or media.get("contentUrl") or ""
    print("   media: content type =", media.get("contentType"), "| stream type =", media.get("streamType"))
    print("   media: address      =", content.split("?")[0])
    print("   media: player state =", status.get("playerState"), "| idle reason =", status.get("idleReason"))
    if media.get("metadata"):
        print("   media: metadata     =", json.dumps(media["metadata"])[:200])


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    probe = Probe(sys.argv[1])
    probe.connect_to(PLATFORM)
    last_app = None
    last_asked = 0.0
    print("Connected. Start mirroring from the other app now. Ctrl+C to stop.")
    while True:
        now = time.time()
        if now - last_asked > 3:
            last_asked = now
            probe.send(PLATFORM, NS_RECEIVER, {"type": "GET_STATUS", "requestId": probe.next_id()})
            probe.send(PLATFORM, NS_HEARTBEAT, {"type": "PING"})
            for destination in list(probe.connected_to - {PLATFORM}):
                probe.send(destination, NS_MEDIA, {"type": "GET_STATUS", "requestId": probe.next_id()})
        for message in probe.read():
            try:
                payload = json.loads(message["payload"])
            except ValueError:
                continue
            kind = payload.get("type")
            if kind == "PING":
                probe.send(message["source"], NS_HEARTBEAT, {"type": "PONG"})
            elif kind == "RECEIVER_STATUS":
                apps = payload.get("status", {}).get("applications", [])
                app = apps[0] if apps else None
                key = json.dumps(app, sort_keys=True)
                if key != last_app:
                    last_app = key
                    if app:
                        describe_app(app)
                        probe.connect_to(app["transportId"])
                    else:
                        print("-" * 60)
                        print("no app running (home screen)")
            elif kind == "MEDIA_STATUS":
                for status in payload.get("status", []):
                    describe_media(status)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
