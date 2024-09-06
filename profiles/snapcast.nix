{ lib, pkgs, hostParams, ... }:
{

  environment.systemPackages = with pkgs; [
    snapcast
  ];

  ## Creates server for all clients (speakers) to connect to
  ## Provides streams from various sources, including pulse audio sink
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

  ## Use local audio (locally connected speaker)
  ## TO DEBUG INSTABILITY:
  ##   https://github.com/badaix/snapcast/issues/774
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
      ${pkgs.snapcast}/bin/snapclient --player alsa:buffer_time=180,fragments=300 --sampleformat 48000:16:* --latency 40 -h ::1

      ## Use pulse instead of alsa
      ## Requires "pactl move-sink-input <sink-input number> 0" after running
      ## Otherwise gets in a feedback loop
      # ${pkgs.snapcast}/bin/snapclient --player pulse -h ::1 --latency 60
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = hostParams.username;
    };
  };


  ## Creates sink for various inputs (mainly bluetooth)
  # systemd.services.snapcast-sink = {
  #   wantedBy = [
  #     "pulseaudio.service"
  #   ];
  #   after = [
  #     "pulseaudio.service"
  #   ];
  #   bindsTo = [
  #     "pulseaudio.service"
  #   ];
  #   path = with pkgs; [
  #     gawk
  #     pulseaudio
  #   ];
  #   script = ''
  #     pactl load-module module-pipe-sink file=/run/snapserver/pulseaudio sink_name=Snapcast format=s16le rate=48000
  #     # pactl set-default-sink Snapcast
  #   '';
  #   serviceConfig = {
  #     ## Needed to get access to pulseaudio
  #     User = hostParams.username;
  #   };
  # };
}

