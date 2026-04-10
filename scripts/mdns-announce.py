#!/usr/bin/env python3
"""Send gratuitous mDNS announcement packets for the Spotify Connect service.

PROBLEM:
  Spotify Connect devices are discovered via mDNS (multicast DNS). When
  librespot starts, its mDNS backend sends an initial burst of announcement
  packets advertising the service. The Spotify app receives these and
  shows the device. However, mDNS records have a TTL (time-to-live) and
  eventually expire. When the Spotify app tries to refresh by sending an
  mDNS query, the query or response often fails to traverse WiFi multicast
  reliably — causing the device to disappear from the Spotify app.

  Wired devices (like the Yamaha Receiver) don't have this problem because
  multicast is reliable on Ethernet.

  Additionally, IPv4 multicast often fails to cross between WiFi and wired
  network segments (through the AP bridge), while IPv6 multicast reliably
  traverses both. So we send announcements on BOTH protocols.

SOLUTION:
  This script sends the same type of mDNS announcement packets that are
  sent at service registration time — unsolicited multicast DNS responses
  containing PTR, SRV, TXT, and address records. A systemd timer runs this
  script every 30 seconds, ensuring the Spotify app's mDNS cache is refreshed
  before the records expire, without needing to restart librespot.

  We send on BOTH IPv4 (224.0.0.251) and IPv6 (ff02::fb) because:
  - IPv4 multicast works WiFi-to-WiFi (sometimes) but NOT WiFi-to-wired
  - IPv6 multicast works reliably in both directions
  - The Spotify app may use either protocol for discovery

IMPORTANT:
  This script must be used with the libmdns backend, NOT avahi. Raw mDNS
  packets on the network cause Avahi to detect name collisions, which
  crashes librespot. libmdns handles mDNS in-process and doesn't conflict.

  Packets MUST be sent from source port 5353 — RFC 6762 requires this,
  and mDNS implementations silently discard responses from other ports.
  We use SO_REUSEADDR to share the port with other mDNS daemons.

  Unique records (SRV, TXT, A/AAAA) have the "cache flush" bit set
  (class=0x8001) to force receivers to replace stale entries. PTR records
  are shared and use regular class (0x0001).

  Packets are spaced 250ms apart because WiFi APs are more likely to drop
  back-to-back multicast frames.
"""

import socket
import struct
import time
import fcntl

# Standard mDNS multicast addresses and port (RFC 6762)
MDNS_ADDR_V4 = "224.0.0.251"
MDNS_ADDR_V6 = "ff02::fb"
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
# Unique records (SRV, TXT, A/AAAA) use cache flush; shared records (PTR) don't.
CLASS_IN = 1            # Regular IN class (for shared PTR records)
CLASS_IN_FLUSH = 0x8001 # IN class with cache flush bit (for unique records)

# WiFi interface name — used to find IPv6 address and interface index
WIFI_INTERFACE = "wlan0"

# ioctl constant for getting interface index (SIOCGIFINDEX)
SIOCGIFINDEX = 0x8933


def get_local_ipv4():
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


def get_interface_index(ifname):
    """Get the numeric interface index for a named network interface.

    Uses the SIOCGIFINDEX ioctl. Needed for IPv6 multicast socket options
    which take an interface index rather than an IP address.
    """
    s = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    try:
        # struct ifreq: 16 bytes for name + padding
        ifr = struct.pack("16sI", ifname.encode("utf-8"), 0)
        result = fcntl.ioctl(s.fileno(), SIOCGIFINDEX, ifr)
        return struct.unpack("16sI", result)[1]
    finally:
        s.close()


def get_ipv6_addresses(ifname):
    """Get global-scope IPv6 addresses for an interface by parsing /proc/net/if_inet6.

    Returns a list of IPv6 address strings. Prefers ULA (fd00::/8) addresses
    over temporary/public addresses since they're stable and local.
    """
    addresses = []
    try:
        with open("/proc/net/if_inet6") as f:
            for line in f:
                parts = line.split()
                # Format: address ifindex prefix_len scope flags ifname
                if len(parts) >= 6 and parts[5] == ifname:
                    addr_hex = parts[0]
                    scope = int(parts[3], 16)
                    # Only global scope (0x00), skip link-local (0x20) and loopback
                    if scope == 0:
                        # Convert hex to proper IPv6 notation
                        addr = ":".join(addr_hex[i:i+4] for i in range(0, 32, 4))
                        addresses.append(addr)
    except FileNotFoundError:
        pass
    # Sort to prefer ULA (fd...) addresses — they're stable and local
    addresses.sort(key=lambda a: (0 if a.startswith("fd") else 1, a))
    return addresses


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


def build_mdns_response(hostname, port, txt_entries, ipv4=None, ipv6=None):
    """Build an mDNS response packet advertising a Spotify Connect service.

    Includes PTR, SRV, TXT records, plus an A record (if ipv4 given)
    and/or AAAA record (if ipv6 given).
    """
    service_type = "_spotify-connect._tcp.local"
    instance_name = f"{hostname}.{service_type}"
    host_target = f"{hostname}.local"

    records = []

    # PTR record (shared — no cache flush): service type -> service instance
    ptr_name = encode_name(service_type)
    ptr_rdata = encode_name(instance_name)
    records.append(
        ptr_name
        + struct.pack("!HHiH", 12, CLASS_IN, RECORD_TTL, len(ptr_rdata))
        + ptr_rdata
    )

    # SRV record (unique — cache flush): service instance -> target host:port
    srv_name = encode_name(instance_name)
    srv_target = encode_name(host_target)
    srv_rdata = struct.pack("!HHH", 0, 0, port) + srv_target
    records.append(
        srv_name
        + struct.pack("!HHiH", 33, CLASS_IN_FLUSH, RECORD_TTL, len(srv_rdata))
        + srv_rdata
    )

    # TXT record (unique — cache flush): service metadata
    txt_name = encode_name(instance_name)
    txt_rdata = encode_txt(txt_entries)
    records.append(
        txt_name
        + struct.pack("!HHiH", 16, CLASS_IN_FLUSH, RECORD_TTL, len(txt_rdata))
        + txt_rdata
    )

    # A record (unique — cache flush): hostname -> IPv4 address
    if ipv4:
        a_name = encode_name(host_target)
        ip_bytes = socket.inet_aton(ipv4)
        records.append(
            a_name
            + struct.pack("!HHiH", 1, CLASS_IN_FLUSH, RECORD_TTL, 4)
            + ip_bytes
        )

    # AAAA record (unique — cache flush): hostname -> IPv6 address
    if ipv6:
        aaaa_name = encode_name(host_target)
        ip6_bytes = socket.inet_pton(socket.AF_INET6, ipv6)
        records.append(
            aaaa_name
            + struct.pack("!HHiH", 28, CLASS_IN_FLUSH, RECORD_TTL, 16)
            + ip6_bytes
        )

    # DNS header: QR=1 (response), AA=1 (authoritative), N answer records
    header = struct.pack("!HHHHHH", 0x0000, 0x8400, 0, len(records), 0, 0)

    return header + b"".join(records)


def send_announcement_ipv4(hostname, ipv4, port, txt_entries):
    """Send a burst of mDNS announcement packets via IPv4 multicast.

    Binds to port 5353 on the device's own IP so packets go out on the
    correct WiFi interface and are accepted by mDNS receivers.
    """
    packet = build_mdns_response(hostname, port, txt_entries, ipv4=ipv4)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((ipv4, MDNS_PORT))
    # TTL of 255 is required by mDNS (RFC 6762 section 11)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(ipv4))

    for _ in range(ANNOUNCEMENT_COUNT):
        sock.sendto(packet, (MDNS_ADDR_V4, MDNS_PORT))
        time.sleep(ANNOUNCEMENT_SPACING)

    sock.close()


def send_announcement_ipv6(hostname, ipv4, ipv6, port, txt_entries, if_index):
    """Send a burst of mDNS announcement packets via IPv6 multicast.

    Includes BOTH A and AAAA records so that IPv6 mDNS clients can learn
    the device's IPv4 address too (important for Spotify Connect which
    may prefer IPv4 for the actual HTTP connection).
    """
    packet = build_mdns_response(hostname, port, txt_entries, ipv4=ipv4, ipv6=ipv6)

    sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    # Bind to port 5353 on all IPv6 interfaces
    sock.bind(("::", MDNS_PORT))
    # TTL of 255 is required by mDNS
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, 255)
    # Send on the correct interface
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, if_index)

    for _ in range(ANNOUNCEMENT_COUNT):
        # ff02::fb requires scope_id (interface index) for link-local multicast
        sock.sendto(packet, (MDNS_ADDR_V6, MDNS_PORT, 0, if_index))
        time.sleep(ANNOUNCEMENT_SPACING)

    sock.close()


def main():
    hostname = socket.gethostname()
    ipv4 = get_local_ipv4()
    txt_entries = ["CPath=/", "VERSION=1.0"]

    # Send IPv4 multicast announcements
    send_announcement_ipv4(hostname, ipv4, ZEROCONF_PORT, txt_entries)
    print(
        f"Sent IPv4 mDNS announcement for "
        f"{hostname}._spotify-connect._tcp.local -> {ipv4}:{ZEROCONF_PORT}"
    )

    # Send IPv6 multicast announcements (includes both A and AAAA records)
    ipv6_addrs = get_ipv6_addresses(WIFI_INTERFACE)
    if ipv6_addrs:
        ipv6 = ipv6_addrs[0]
        try:
            if_index = get_interface_index(WIFI_INTERFACE)
            send_announcement_ipv6(hostname, ipv4, ipv6, ZEROCONF_PORT, txt_entries, if_index)
            print(
                f"Sent IPv6 mDNS announcement for "
                f"{hostname}._spotify-connect._tcp.local -> [{ipv6}]:{ZEROCONF_PORT}"
            )
        except Exception as e:
            print(f"IPv6 announcement failed (non-fatal): {e}")
    else:
        print("No global IPv6 address found, skipping IPv6 announcement")


if __name__ == "__main__":
    main()
