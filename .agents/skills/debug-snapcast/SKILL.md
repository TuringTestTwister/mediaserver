---
name: debug-snapcast
description: Diagnose Snapcast streaming issues across mediaserver hosts (no audio, dropouts, "switching to idle", a stream that the controller can't connect to). Walks the audio → pipe → snapserver → network → snapclient chain in that order so network problems aren't mistaken for snapcast problems.
---

# Debugging snapcast issues

The mediaserver setup has two roles. Diagnose them in order — most "snapcast is broken" reports turn out to be network problems masquerading as audio problems.

- **snapserver** runs on a *source* host. It reads from a pipe (`/tmp/pipewire_snapcast_pipe`, `/run/snapserver/<name>`) that is fed by the local audio system (PipeWire/PulseAudio sink → pipe-sink module, or an app writing the pipe directly).
- **snapclient** runs on a *consumer* host. On the controller (`partymusic`) there is one `snapclient-<name>` instance per remote source defined in `mediaserver-config/flake.nix` `snapcastControllerStreams`; each connects to that source's IP on TCP 1704 and pipes the stream into `/run/snapserver/<name>` so the local snapserver can re-broadcast it.

Walk the chain end-to-end. Stop at the first broken link.

## 1. Identify which side is broken

- Look at `mediaserver-config/flake.nix` to see which streams the controller pulls (name → IP).
- The "source" is the host with that IP, running `snapserver`. The "consumer" pulling it is `partymusic`, running `snapclient-<name>`.

## 2. Audio pipeline checks (on the source)

```
systemctl --user status pipewire pipewire-pulse   # or `systemctl status pulseaudio` on partymusic
pactl info | grep -E "Default Sink|Default Source"
pw-link -l | grep -A1 -B1 snapcast                # links into the snapcast sink
pactl list sources short | grep snapcast          # snapcast.monitor should be RUNNING at 44100Hz
pactl list sink-inputs                            # is anything actually playing?
ls -la /tmp/pipewire_snapcast_pipe                # the pipe snapserver reads
```

Default sink should be the snapcast sink (or audio should be routed to it via easyeffects/loopback). If `snapcast.monitor` is `SUSPENDED` or there are no sink inputs, no audio is being captured — fix the source side first.

## 3. Snapserver checks (on the source)

```
systemctl status snapserver
ss -tln | grep -E "1704|1705|1780"               # listening?
cat /etc/snapserver.conf                          # check `source = ...` URIs
journalctl -u snapserver -n 50
```

Look for `onResync (<stream>)` lines (good — data is flowing) vs `No data since 5020 ms in stream '<name>', switching to idle` (the pipe is empty, audio side is broken).

## 4. Network checks (the often-overlooked step)

This is the step people skip. **Do it before deeper snapcast debugging.**

From the consumer:

```
ping <source-ip>
nc -zv <source-ip> 1704
```

If either fails, **stop debugging snapcast** — it's a network problem. Common causes:

- **Tailscale subnet routes hijacking the LAN.** If a peer (e.g. `homefree`) advertises `10.0.0.0/24` as a subnet route and the host has `RouteAll: true`, the kernel will route replies for 10.0.0.x out `tailscale0` instead of `wlan0` even when the host is sitting on the LAN. Inbound SYNs arrive on `wlan0`, replies go out `tailscale0` → asymmetric → connection times out. SSH and ICMP fail too — that's the giveaway it's not snapcast.

  Diagnose on the source:
  ```
  ip route get <consumer-ip>             # is the path the expected interface?
  ip rule                                # look for a tailscale rule (priority ~5270 → table 52)
  tailscale debug prefs | grep RouteAll  # accepting routes?
  tailscale status                       # which peer advertises 10.0.0.0/24?
  ```

  Quick fix: `sudo ip rule add to 10.0.0.0/24 lookup main priority 5195`. Durable fix: a `tailscale-local-route.service` that adds that rule when (and only when) the host is on-LAN. There's a working version in `~/Code/nixcfg/modules/networking/tailscale/default.nix` — note the gotcha that the service must wait for *both* tailscale0 and a 10.0.0.x DHCP lease before deciding "off LAN", or it races DHCP at boot and the rule never gets installed.

- **NixOS firewall.** `1704/1705/1780` must be in `networking.firewall.allowedTCPPorts`. Confirm by reading `/run/current-system`'s firewall-start script: `cat /nix/store/*-firewall-start/bin/firewall-start | grep -E "dport (1704|1705|1780)"`.

- **AP isolation / different subnets.** `ip -4 addr` on both ends; if they're on different /24s, routing must be in place.

## 5. Snapclient checks (on the consumer)

```
systemctl status snapclient-<name>                # for controller-side per-source instances
ls -la --time-style=full /run/snapserver/<name>   # FIFO mtime — should be very recent
journalctl -u snapclient-<name> -n 30
```

A stale mtime on the FIFO means snapclient isn't getting data from the source. Combined with `nc -zv` failing, it's network. Combined with `nc -zv` succeeding but `journalctl` showing repeated reconnects, look at the source's snapserver logs.

## 6. Snapweb / controller selection

Even with everything healthy, audio only plays if the consumer has the right source selected. Check the snapweb UI at `http://partymusic.lan:1780/` (or via the touch UI).

## Worked example: p16 silent on 2026-05-10

Symptom: Brave was playing on `nflx-erahhal-p16` (10.0.0.62), the laptop's snapserver was healthy and `/tmp/pipewire_snapcast_pipe` was being written, but partymusic's snapserver had logged `'p16' switching to idle` and no audio was coming out.

Diagnosis:

- Source-side audio chain was fine: `pw-link -l` showed `snapcast:playback ← ee_soe_output_level`, `snapcast.monitor` was `RUNNING`, `pactl list sink-inputs` showed Brave playing.
- `ss -tln` confirmed snapserver listening on 1704/1705/1780.
- From partymusic: `ping 10.0.0.62` was 100% loss, `nc -zv 10.0.0.62 22` (SSH!) also timed out — clearly not a snapcast issue.
- On the laptop: `ip route get 10.0.0.1` returned `dev tailscale0 table 52 src 100.64.0.9`. Tailscale peer `homefree` advertises `10.0.0.0/24` and the laptop had `RouteAll: true`, so all 10.0.0.x replies were being misrouted.
- The laptop's `tailscale-local-route.service` was supposed to prevent exactly this, but at boot it had run before wlan0 finished DHCP, so its "is there a 10.0.0.x address?" check returned no, it logged "Off LAN -- skipped policy rule", and never re-evaluated.

Fix: `sudo ip rule add to 10.0.0.0/24 lookup main priority 5195` immediately restored connectivity (snapclient-p16 reconnected automatically because it has `Restart=always`). Durable fix patched `tailscale-local-route.service` to also wait for a 10.0.0.x address (with timeout falling through to off-LAN) before the on-LAN check.
