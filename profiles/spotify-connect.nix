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
  zeroconf-backend = "avahi";
  # zeroconf-backend = "dns-sd";
  ## Doesn't seem to work
  # zeroconf-backend = "libmdns";
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

  systemd.services = {
    spotify-connect = {
      description = "Spotify Connect Daemon";
      after = [ "snapclient.service" "network-online.target" ];
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

