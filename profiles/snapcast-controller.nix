{ config, lib, pkgs, ... }:
let
  # Stream of streams
  main-location = "/bluetooth/" ++ lib.strings.concatStringsSep "/" (
    lib.lists.map (stream: stream.name) config.mediaserver.snapcastControllerStreams
  );
  # mediaserver
  # speakerserver
  # p16
  # work_dock
  # antikythera
  # antikytheradock
  streams = lib.listToAttrs (lib.imap0 (index: stream: {
    name = stream.name;
    value = {
      type = "pipe";
      location = "/run/snapserver/${stream.name}";
      query = {
        mode = "create";
        dryout_ms = "2000";
        send_silence = "false";
        idle_threshold = "5000";
        silence_threshold_percent = "1.0";
      };
    };
  }) config.mediaserver.snapcastControllerStreams);
  # snapclients that stream to pipes
  services = lib.listToAttrs (lib.imap0 (index: stream: {
    name = "snapclient-${stream.name}";
    value = {
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
        # @TODO: try this with hostname instead, or do a lookup before running
        snapclient --logsink null --instance ${toString (index + 3)} -h ${stream.ip-address} --player file > /run/snapserver/${stream.name}
      '';
      serviceConfig = {
        User = config.mediaserver.username;
      };
    };
  }) config.mediaserver.snapcastControllerStreams);
in
{
  services.snapserver = {
    streams = {
      main.location = lib.mkForce main-location;
    } // streams;
  };

  systemd.services = services;
}
