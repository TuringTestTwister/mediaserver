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
    codec = "flac";
    sampleFormat = "44100:16:2";
    streams = {
      Main = {
        type = "meta";
        location = "/Spotify/Bluetooth";
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
      ${pkgs.snapcast}/bin/snapclient --player alsa:buffer_time=120,fragments=300 --sampleformat 44100:16:* --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}
      # ${pkgs.snapcast}/bin/snapclient --player alsa --sampleformat 48000:24:* --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}
      # ${pkgs.snapcast}/bin/snapclient --player alsa --latency ${hostParams.snapcastLatency} -h ${hostParams.snapcastServerHost}

      ## Use pulse instead of alsa
      ## Requires "pactl move-sink-input <sink-input number> 0" after running
      ## Otherwise gets in a feedback loop
      # ${pkgs.snapcast}/bin/snapclient --player pulse -h ::1
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
      gawk
      pulseaudio
    ];
    script = ''
      pactl load-module module-pipe-sink file=/run/snapserver/bluetooth sink_name=Snapcast format=s16le rate=44100
      # pactl load-module module-pipe-sink file=/run/snapserver/main sink_name=Snapcast format=s16le rate=44100
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
  systemd.services.pulseaudio-loopback-update-latency= {
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
      source_number=""

      ## new_source is used to make sure loopback is only ever reloaded once
      new_source=0
      pactl subscribe | while read x event y type num; do
        if [ $event == "'new'" -a $type == 'source' ]; then
          echo "event: $event, type: $type, num: $num"
          new_source=1
	  echo "unloading module-loopback"
          pactl unload-module module-loopback
	  echo "reloading module-loopback with input latency of 500ms"
          pactl load-module module-loopback latency_msec=500
        fi

        ## @TODO: Verify that there is no need to wait for source-output events before loading module-loopback above
        # if [ $event == "'new'" -a $type == 'source-output' -a $new_source == '1' ]; then
	#   echo "type: $type"
        #   pactl unload-module module-loopback
        #   pactl load-module module-loopback latency_msec=500
        #   new_source=0
        # fi
      done
    '';
    serviceConfig = {
      ## Needed to get access to pulseaudio
      User = hostParams.username;
    };
  };

}

