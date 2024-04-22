{ lib, pkgs, hostParams, ... }:
{
  services.snapserver = {
    enable = true;
    codec = "flac";
    streams = {
      pipewire  = {
        type = "pipe";
        location = "/run/snapserver/pipewire";
      };
    };
  };

  # systemd.services.snapcast-sink = {
  #   wantedBy = [
  #     "pipewire.service"
  #   ];
  #   after = [
  #     "pipewire.service"
  #   ];
  #   bindsTo = [
  #     "pipewire.service"
  #   ];
  #   path = with pkgs; [
  #     gawk
  #     pulseaudio
  #   ];
  #   script = ''
  #     pactl load-module module-pipe-sink file=/run/snapserver/pipewire sink_name=Snapcast format=s16le rate=48000
  #   '';
  # };

  networking.firewall.allowedTCPPorts = [ 1704 1705  ];
}

