{ config, lib, pkgs, ... }:
let
  device-name = config.mediaserver.hostname;
  bitrate = "320";
  cache-args = "--disable-audio-cache";
  # cache-args = "--cache /var/cache/raspotify";
  volume-args = "--enable-volume-normalisation --volume-ctrl=linear --initial-volume=100";
  # backend-args = "--backend=alsa";
  backend-args = "--backend=pipe --device=/run/snapserver/spotify";
  # backend-args = "--backend=pipe --device=/run/snapserver/main";
  zeroconf-port-udp = 5353;
  zeroconf-port-tcp = 5354;
  # zeroconf-backend = "avahi";
  # zeroconf-backend = "dns-sd";
  # Using libmdns (in-process mDNS) instead of avahi because our periodic
  # mDNS re-announcement script causes Avahi name collisions that crash librespot.
  # libmdns handles mDNS internally, so raw announcement packets don't conflict.
  zeroconf-backend = "libmdns";
  zeroconf-args = "--zeroconf-port=${toString zeroconf-port-tcp} --zeroconf-backend ${zeroconf-backend}";
  ## Allows for seeing device across the internet
  # options = "--username <USERNAME> --password <PASSWORD>";
  # debug-args = "--verbose";
  debug-args = "--verbose";
in
{
  imports = [
    ../overlays/librespot-zeroconf.nix
  ];

  environment.systemPackages = [
    pkgs.librespot
  ];

  # WiFi multicast is unreliable: mDNS records advertised by librespot/Avahi
  # get cached by the Spotify app, but when the cache expires, the follow-up
  # mDNS query/response often fails to traverse WiFi. The device then
  # disappears from the Spotify app. This timer sends gratuitous mDNS
  # announcements every 30 seconds to keep the cache fresh. See
  # scripts/mdns-announce.py for full explanation.
  systemd.timers.spotify-connect-reannounce = {
    description = "Periodically send mDNS announcements for Spotify Connect";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnActiveSec = "30s";
      OnUnitActiveSec = "30s";
    };
  };

  systemd.services = {
    spotify-connect-reannounce = {
      description = "Send gratuitous mDNS announcement for Spotify Connect";
      after = [ "spotify-connect.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${../scripts/mdns-announce.py}";
      };
    };

    spotify-connect = {
      description = "Spotify Connect Daemon";
      after = [ "snapserver.service" "network-online.target" ];
      requires = [ "snapserver.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ## Needed to get access to pulseaudio
        User = config.mediaserver.username;
        Group = "users";
        # User = "root";
        # Group = "root";
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 10;
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -p /run/snapserver/spotify ]; do sleep 1; done'";
        ExecStart = "${pkgs.librespot}/bin/librespot --name '${device-name}' ${zeroconf-args} ${backend-args} --bitrate ${bitrate} ${cache-args} ${volume-args} ${debug-args}";
      };
    };
  };

  system.activationScripts.makeSpotifyConnectCacheDir = lib.stringAfter [ "var" ] ''
    mkdir -p /var/cache/spotify-connect
  '';

  networking.firewall.allowedUDPPorts = [ zeroconf-port-udp ];
  networking.firewall.allowedTCPPorts = [ zeroconf-port-tcp ];

  # Allow non-root users to publish services via Avahi
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  # # Workaround for librespot discovery issues
  # # https://forum.libreelec.tv/thread/25931-librespot-no-longer-works/
  # networking.extraHosts = ''
  #   0.0.0.0 apresolve.spotify.com
  # '';
}

