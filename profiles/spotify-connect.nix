{ lib, pkgs, hostParams, ... }:
let
  device-name = "mediaserver";
  bitrate = "320";
  cache-args = "--disable-audio-cache";
  # cache-args = "--cache /var/cache/raspotify";
  volume-args = "--enable-volume-normalisation --volume-ctrl=linear --initial-volume=100";
  # backend-args = "--backend=alsa";
  backend-args = "--backend=pipe --device=/run/snapserver/pulseaudio";
  zeroconf-port = 5354;
  zeroconf-args = "--zeroconf-port=${toString zeroconf-port}";
  ## Allows for seeing device across the internet
  # options = "--username <USERNAME> --password <PASSWORD>";
in
{
  systemd.services = {
    spotify-connect = {
      description = "Spotify Connect Daemon";
      after = [ "spanclient.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ## Needed to get access to pulseaudio
        User = hostParams.username;
        Group = "users";
        # User = "root";
        # Group = "root";
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 10;
        ExecStart = "${pkgs.librespot}/bin/librespot --name '${device-name}' ${zeroconf-args} ${backend-args} --bitrate ${bitrate} ${cache-args} ${volume-args} --verbose";
      };
    };
  };

  system.activationScripts.makeSpotifyConnectCacheDir = lib.stringAfter [ "var" ] ''
    mkdir -p /var/cache/spotify-connect
  '';

  networking.firewall.allowedTCPPorts = [ zeroconf-port ];
}

