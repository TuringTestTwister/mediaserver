#!/usr/bin/env python3
"""Send gratuitous mDNS announcement packets for the Spotify Connect service.

PROBLEM:
  Spotify Connect devices are discovered via mDNS (multicast DNS). When
  librespot starts, Avahi sends an initial burst of mDNS announcement
  packets advertising the service. The Spotify app receives these and
  shows the device. However, mDNS records have a TTL (time-to-live) and
  eventually expire. When the Spotify app tries to refresh by sending an
  mDNS query, the query or response often fails to traverse WiFi multicast
  reliably — causing the device to disappear from the Spotify app.

  Wired devices (like the Yamaha Receiver) don't have this problem because
  multicast is reliable on Ethernet.

SOLUTION:
  This script sends the same type of mDNS announcement packets that Avahi
  sends at service registration time — unsolicited multicast DNS responses
  containing PTR, SRV, TXT, and A records. A systemd timer runs this script
  every 30 seconds, ensuring the Spotify app's mDNS cache is refreshed
  before the records expire, without needing to restart librespot.

  Key details that make this work (learned through debugging):
  - Packets MUST be sent from source port 5353. RFC 6762 requires this,
    and mDNS implementations silently discard responses from other ports.
    We use SO_REUSEADDR to share port 5353 with the Avahi daemon.
  - Unique records (SRV, TXT, A) MUST have the "cache flush" bit set
    (bit 15 of the DNS class field, i.e. class=0x8001 instead of 0x0001).
    This tells receivers to replace stale cached entries immediately.
  - PTR records must NOT have cache flush set (they are shared records).
  - Packets are spaced 250ms apart because WiFi access points are more
    likely to drop back-to-back multicast frames.
"""

import socket
import struct
import time

# Standard mDNS multicast address and port (RFC 6762)
MDNS_ADDR = "224.0.0.251"
MDNS_PORT = 5353

# Must match the port librespot listens on for Spotify Connect HTTP requests
ZEROCONF_PORT = 5354

# Number of announcement packets per burst. More packets = higher chance
# at least one gets through unreliable WiFi multicast.
ANNOUNCEMENT_COUNT = 5

# Delay between packets in a burst (seconds). Spacing them out avoids
# WiFi frame aggregation which can cause the AP to drop the whole batch.
ANNOUNCEMENT_SPACING = 0.25

# How long (seconds) other devices should cache these records.
# Should be longer than the announcement interval (30s) to avoid gaps.
RECORD_TTL = 120

# DNS class values. "Cache flush" (bit 15) tells receivers to replace
# any existing cached records for this name+type, rather than merging.
# Unique records (SRV, TXT, A) use cache flush; shared records (PTR) don't.
CLASS_IN = 1            # Regular IN class (for shared PTR records)
CLASS_IN_FLUSH = 0x8001 # IN class with cache flush bit (for unique records)


def get_local_ip():
    """Get the primary local IPv4 address by briefly connecting a UDP socket.

    This doesn't actually send any traffic — it just lets the OS routing
    table tell us which interface would be used to reach the network.
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    finally:
        s.close()


def encode_name(name):
    """Encode a DNS name in the standard wire format (length-prefixed labels).

    Example: "foo.local" -> b'\\x03foo\\x05local\\x00'
    """
    result = b""
    for part in name.split("."):
        encoded = part.encode("utf-8")
        result += struct.pack("B", len(encoded)) + encoded
    result += b"\x00"
    return result


def encode_txt(entries):
    """Encode DNS TXT record entries as length-prefixed strings.

    Each entry is a key=value string like "CPath=/" or "VERSION=1.0".
    """
    result = b""
    for entry in entries:
        encoded = entry.encode("utf-8")
        result += struct.pack("B", len(encoded)) + encoded
    return result


def build_mdns_response(hostname, ip, port, txt_entries):
    """Build an mDNS response packet advertising a Spotify Connect service.

    The packet contains four DNS resource records:
      - PTR:  _spotify-connect._tcp.local -> hostname._spotify-connect._tcp.local
              (shared record — tells browsers "this service instance exists")
      - SRV:  hostname._spotify-connect._tcp.local -> hostname.local:port
              (unique record with cache flush — tells clients where to connect)
      - TXT:  hostname._spotify-connect._tcp.local -> CPath=/, VERSION=1.0
              (unique record with cache flush — Spotify Connect protocol metadata)
      - A:    hostname.local -> IPv4 address
              (unique record with cache flush — resolves hostname to IP)
    """
    service_type = "_spotify-connect._tcp.local"
    instance_name = f"{hostname}.{service_type}"
    host_target = f"{hostname}.local"

    # DNS header flags: QR=1 (response), AA=1 (authoritative), 4 answer records
    header = struct.pack("!HHHHHH", 0x0000, 0x8400, 0, 4, 0, 0)

    # PTR record (shared — no cache flush): service type -> service instance
    ptr_name = encode_name(service_type)
    ptr_rdata = encode_name(instance_name)
    ptr_record = (
        ptr_name
        + struct.pack("!HHiH", 12, CLASS_IN, RECORD_TTL, len(ptr_rdata))
        + ptr_rdata
    )

    # SRV record (unique — cache flush): service instance -> target host:port
    srv_name = encode_name(instance_name)
    srv_target = encode_name(host_target)
    srv_rdata = struct.pack("!HHH", 0, 0, port) + srv_target
    srv_record = (
        srv_name
        + struct.pack("!HHiH", 33, CLASS_IN_FLUSH, RECORD_TTL, len(srv_rdata))
        + srv_rdata
    )

    # TXT record (unique — cache flush): service metadata
    txt_name = encode_name(instance_name)
    txt_rdata = encode_txt(txt_entries)
    txt_record = (
        txt_name
        + struct.pack("!HHiH", 16, CLASS_IN_FLUSH, RECORD_TTL, len(txt_rdata))
        + txt_rdata
    )

    # A record (unique — cache flush): hostname -> IPv4 address
    a_name = encode_name(host_target)
    ip_bytes = socket.inet_aton(ip)
    a_record = (
        a_name
        + struct.pack("!HHiH", 1, CLASS_IN_FLUSH, RECORD_TTL, 4)
        + ip_bytes
    )

    return header + ptr_record + srv_record + txt_record + a_record


def send_mdns_announcement(hostname, ip, port, txt_entries):
    """Send a burst of mDNS announcement packets via IPv4 multicast.

    IMPORTANT: We must send from source port 5353 (the standard mDNS port).
    RFC 6762 requires this, and most mDNS implementations silently ignore
    responses from other source ports. We use SO_REUSEADDR to coexist with
    the Avahi daemon which is already bound to the same port.
    """
    packet = build_mdns_response(hostname, ip, port, txt_entries)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    # Allow sharing port 5353 with Avahi daemon
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    # Bind to port 5353 on the correct interface — mDNS responses MUST
    # originate from port 5353 or receivers will ignore them
    sock.bind((ip, MDNS_PORT))
    # TTL of 255 is required by mDNS (RFC 6762 section 11)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
    # Send multicast on the correct network interface
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(ip))

    for _ in range(ANNOUNCEMENT_COUNT):
        sock.sendto(packet, (MDNS_ADDR, MDNS_PORT))
        time.sleep(ANNOUNCEMENT_SPACING)

    sock.close()


def main():
    hostname = socket.gethostname()
    ip = get_local_ip()
    txt_entries = ["CPath=/", "VERSION=1.0"]

    send_mdns_announcement(hostname, ip, ZEROCONF_PORT, txt_entries)
    print(
        f"Sent mDNS announcement for "
        f"{hostname}._spotify-connect._tcp.local -> {ip}:{ZEROCONF_PORT}"
    )


if __name__ == "__main__":
    main()
