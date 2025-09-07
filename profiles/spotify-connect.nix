{ config, lib, pkgs, ... }:
let
  device-name = config.mediaserver.hostName;
  bitrate = "320";
  cache-args = "--disable-audio-cache";
  # cache-args = "--cache /var/cache/raspotify";
  volume-args = "--enable-volume-normalisation --volume-ctrl=linear --initial-volume=100";
  # backend-args = "--backend=alsa";
  backend-args = "--backend=pipe --device=/run/snapserver/spotify";
  # backend-args = "--backend=pipe --device=/run/snapserver/main";
  zeroconf-port = 5354;
  zeroconf-args = "--zeroconf-port=${toString zeroconf-port}";
  ## Allows for seeing device across the internet
  # options = "--username <USERNAME> --password <PASSWORD>";
  # debug-args = "--verbose";
  debug-args = "--verbose";
in
{
  imports = [
    ../overlays/librespot-dev.nix
  ];

  environment.systemPackages = [
    pkgs.librespot
  ];

  systemd.services = {
    spotify-connect = {
      description = "Spotify Connect Daemon";
      after = [ "spanclient.service" ];
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

  networking.firewall.allowedTCPPorts = [ zeroconf-port ];
}

