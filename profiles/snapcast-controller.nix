{ config, lib, pkgs, ... }:
let
  # Stream of streams
  main-location = "/bluetooth/spotify/" + (lib.strings.concatStringsSep "/" (
    lib.lists.map (stream: stream.name) config.mediaserver.snapcastControllerStreams
  ));
  # Individual remote streams
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
  # snapclients that direct remote streams to pipes
  services = lib.listToAttrs (lib.imap0 (index: stream: {
    name = "snapclient-${stream.name}";
    value = {
      wantedBy = [
        "snapserver.service"
      ];
      after = [
        "snapserver.service"
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
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        User = config.mediaserver.username;
      };
    };
  }) config.mediaserver.snapcastControllerStreams);
in
{
  services.snapserver = if config.mediaserver.snapcastController then {
    streams = {
      main.location = lib.mkForce main-location;
    } // streams;
  } else {};

  systemd.services = if config.mediaserver.snapcastController then services else {};
}
