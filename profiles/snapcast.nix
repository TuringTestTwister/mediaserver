{ lib, pkgs, hostParams, ... }:
let
  snapweb = pkgs.callPackage ../pkgs/snapweb {};
  # "-s sysdefault" selects "headphone" alsa device
  snapclientSoundcardParam = if hostParams.forceHeadphoneOutput then "-s sysdefault" else "";
in
{
  environment.systemPackages = with pkgs; [
    snapcast
  ];

  imports = if hostParams.controller then [
    ./snapcast-controller.nix
  ] else [];

  ## Creates server for all clients (speakers) to connect to
  ## Provides streams from various sources, including pulse audio sink
  services.snapserver = {
    enable = true;
    codec = "flac";
    sampleFormat = "44100:16:2";
    streams = {
      Main = {
        type = "meta";
        ## Prioritize bluetooth over spotify
        location = "/Bluetooth/Spotify";
      };
      Spotify = {
        type = "pipe";
        location = "/run/snapserver/spotify";
      };
      Bluetooth = {
        type = "pipe";
        location = "/run/snapserver/bluetooth";
        ## Per stream sampleformat doesn't seem to work
        # sampleFormat = "48000:24:2";
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
      snapclient ${snapclientSoundcardParam} --player alsa:buffer_time=120,fragments=300 --sampleformat 44100:16:* --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = hostParams.username;
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
      User = hostParams.username;
    };
  };

  hardware.pulseaudio = {
    extraConfig = ''
      # Don't switch sources on detection
      unload-module module-switch-on-port-available
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
    script = ''
      source_number=""

      ## new_source is used to make sure loopback is only ever reloaded once
      while [ true ]; do
        pactl subscribe | while read x event y type num; do
          if [ $event == "'new'" -a $type == 'source' ]; then
            echo "event: $event, type: $type, num: $num"
            SOURCE=$(pactl list short sources | grep bluez_source | awk '{ print $2 }') 
            if [ ! -z "$SOURCE" ]; then
              echo "unloading module-loopback"
              pactl unload-module module-loopback
              echo "Loading bluetooth loopback to fifo with input latency of 500ms"
              echo "source: $SOURCE, sink: BluetoothFifo"
              pactl load-module module-loopback latency_msec=500 format=s16le rate=44100 channels=2 source=$SOURCE sink=BluetoothFifo source_dont_move=true sink_dont_move=true
              retval=$?
              if [ $retval -ne 0 ]; then
                # start subscription again on failure. it seems to get stuck
	        break
              fi
            fi 
          fi
        done
      done
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = hostParams.username;
    };
  };

}

