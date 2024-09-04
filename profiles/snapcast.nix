{ lib, pkgs, hostParams, ... }:
{
  services.snapserver = {
    enable = true;
    codec = "flac";
    streams = {
      Pulseaudio  = {
        type = "pipe";
        location = "/run/snapserver/pulseaudio";
      };
    };
    openFirewall = true;
  };

  # Should not be needed with openFirewall property above also set
  networking.firewall.allowedTCPPorts = [ 1704 1705 1780 ];

  systemd.services.snapclient = {
    wantedBy = [
      "pulseaudio.service"
    ];
    after = [
      "pulseaudio.service"
    ];
    path = with pkgs; [
      pulseaudio
      snapcast
    ];
    script = ''
      ${pkgs.snapcast}/bin/snapclient -h ::1
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = hostParams.username;
    };
  };


  systemd.services.snapcast-sink = {
    wantedBy = [
      "pulseaudio.service"
    ];
    after = [
      "pulseaudio.service"
    ];
    bindsTo = [
      "pulseaudio.service"
    ];
    path = with pkgs; [
      gawk
      pulseaudio
    ];
    script = ''
      pactl load-module module-pipe-sink file=/run/snapserver/pulseaudio sink_name=Snapcast format=s16le rate=48000
      pactl set-default-sink Snapcast
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = hostParams.username;
    };
  };
}

