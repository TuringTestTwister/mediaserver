{ lib, pkgs, hostParams, ... }:
let
  snapweb = pkgs.callPackage ../pkgs/snapweb {};
in
{

  environment.systemPackages = with pkgs; [
    snapcast
  ];

  ## Creates server for all clients (speakers) to connect to
  ## Provides streams from various sources, including pulse audio sink
  services.snapserver = {
    enable = true;
    codec = if hostParams.controller == true then "flac" else "pcm";
    sampleFormat = "44100:16:2";
    streams = lib.mkMerge [
      {
        Main = {
          type = "meta";
          ## Prioritize bluetooth over spotify
          location = if hostParams.controller == true then "/Bluetooth/mediaserver/speakerserver/Spotify" else "/Bluetooth/Spotify";
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
      }
      (if hostParams.controller == true then {
        mediaserver = {
          type = "tcp";
          query = {
            mode = "client";
          };
          location = "10.0.0.32:1704"; # default port 4953
        };
        speakerserver = {
          type = "tcp";
          query = {
            mode = "client";
          };
          location = "10.0.0.28:1704"; # default port 4953
        };
      } else {})
    ];
    openFirewall = true;
    http = {
      enable = true;
      ## @TODO: Change this to a custom package that gets a release from github:
      ## https://github.com/badaix/snapweb/releases
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
      # "-s 2" selects "headphone" alsa device
      ${pkgs.snapcast}/bin/snapclient -s 2 --player alsa:buffer_time=120,fragments=300 --sampleformat 44100:16:* --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}

      # pactl set-default-sink 0
      # ${pkgs.snapcast}/bin/snapclient --player pulse --sampleformat 44100:16:* --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}
      # ${pkgs.snapcast}/bin/snapclient --player alsa --sampleformat 48000:24:* --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}
      # ${pkgs.snapcast}/bin/snapclient --player alsa --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}

      ## Use pulse instead of alsa
      ## Requires "pactl move-sink-input <sink-input number> 0" after running
      ## Otherwise gets in a feedback loop
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

