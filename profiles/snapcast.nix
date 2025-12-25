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
    openFirewall = true;
    http = {
      enable = true;
      docRoot = "${snapweb}/share/html";
    };
    settings = {
      stream = {
        codec = "flac";
        sampleformat = "44100:16:2";
        source = [
          # Pipe sources for bluetooth and spotify
          "pipe:///run/snapserver/bluetooth?name=bluetooth"
          "pipe:///run/snapserver/spotify?name=spotify"
          # Meta source combines bluetooth and spotify, prioritizing bluetooth
          "meta:///bluetooth/spotify?name=main"
        ];
      };
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
      "snapserver.service"
    ];
    after = [
      "snapserver.service"
      "pulseaudio.service"
    ];
    # @TODO: Does this restart this service when snapserver restarts?
    bindsTo = [
      "snapserver.service"
    ];
    path = with pkgs; [
      pulseaudio
    ];
    script = ''
      pactl unload-module module-pipe-sink 2>&1 | true
      pactl load-module module-pipe-sink file=/run/snapserver/bluetooth sink_name=BluetoothFifo format=s16le rate=44100 channels=2
      # pactl load-module module-pipe-sink file=/run/snapserver/main sink_name=Snapcast format=s16le rate=44100 channels=2
    '';
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
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

    # Configure daemon settings for proper resampling
    daemon.config = {
      # Set the default and alternate sample rates
      default-sample-rate = 44100;
      ## Needed for bluetooth output
      alternate-sample-rate = 48000;

      # Enable automatic resampling with high quality
      resample-method = "speex-float-5";

      # Allow PulseAudio to automatically adjust rates
      ## Needed for bluetooth output
      avoid-resampling = false;

      # Enable rate adjustment for better Bluetooth compatibility
      enable-remixing = true;
      enable-lfe-remixing = false;

      # Set default sample format
      default-sample-format = "s16le";
    };
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

