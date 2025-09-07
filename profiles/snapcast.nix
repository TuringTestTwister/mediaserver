{ config, pkgs, ... }:
let
  snapweb = pkgs.callPackage ../pkgs/snapweb {};
  # "-s sysdefault" selects "headphone" alsa device
  snapclientSoundcardParam = if config.mediaserver.forceHeadphoneOutput then "-s sysdefault" else "";
in
{
  environment.systemPackages = with pkgs; [
    snapcast
  ];

  imports = [
    ./snapcast-controller.nix
  ];

  ## Creates server for all clients (speakers) to connect to
  ## Provides streams from various sources, including pulse audio sink
  services.snapserver = {
    enable = true;
    codec = "flac";
    sampleFormat = "44100:16:2";
    streams = {
      # Nix writes these in alphabetical order, and the first one is the default, hence the prefixes
      main = {
        type = "meta";
        ## Prioritize bluetooth over spotify
        location = "/bluetooth/spotify";
      };
      bluetooth = {
        type = "pipe";
        location = "/run/snapserver/bluetooth";
        ## Per stream sampleformat doesn't seem to work
        # sampleFormat = "48000:24:2";
      };
      spotify = {
        type = "pipe";
        location = "/run/snapserver/spotify";
      };
    };
    openFirewall = true;
    http = {
      enable = true;
      docRoot = "${snapweb}/share/html";
    };
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
      snapclient ${snapclientSoundcardParam} --instance 1 --player alsa:buffer_time=120,fragments=300 --sampleformat 44100:16:* --latency ${toString config.mediaserver.snapcastLatency} -h ${config.mediaserver.snapcastServerHost}
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = config.mediaserver.username;
    };
  };

  ## Creates sink for various inputs (mainly bluetooth)
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
      pulseaudio
    ];
    script = ''
      pactl load-module module-pipe-sink file=/run/snapserver/bluetooth sink_name=BluetoothFifo format=s16le rate=44100 channels=2
      # pactl load-module module-pipe-sink file=/run/snapserver/main sink_name=Snapcast format=s16le rate=44100 channels=2
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = config.mediaserver.username;
    };
  };

  services.pulseaudio = {
    extraConfig = ''
      # Don't switch sources on detection
      unload-module module-switch-on-port-available

      # Don't load module-loopback for bluetooth devices
      unload-module module-bluetooth-policy
      load-module module-bluetooth-policy a2dp_source=false auto_switch=false
    '';
  };

  ## Pulseaudio downsamples audio from Bluetooth, and module-loopback
  ## experiences buffer underruns. It bumps the input latency by 5ms every time
  ## it has an underrun, but this can take minutes before audio stabilizes.
  ## Instead, reload the module-loopback with higher latency once a new source
  ## (in this case, a bluetooth connection) is detected.
  systemd.services.pulseaudio-event-handler = {
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
      gnugrep
      pulseaudio
    ];
    script = "${./pulseaudio-event-handler.sh}";
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = config.mediaserver.username;
    };
  };
}

