{ config, lib, pkgs, ... }:
let
  cfg = config.mediaserver;

  remoteStreamNames = lib.lists.map (stream: stream.name) cfg.snapcastControllerStreams;

  # Generate pipe source URIs for remote streams
  remotePipeSources = lib.lists.map (stream:
    "pipe:///run/snapserver/${stream.name}?name=${stream.name}&mode=create&dryout_ms=2000&send_silence=false&idle_threshold=5000&silence_threshold_percent=1.0"
  ) cfg.snapcastControllerStreams;

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
        User = cfg.username;
        Restart = "always";
        RestartSec = 5;
      };
    };
  }) cfg.snapcastControllerStreams);
in
lib.mkIf cfg.snapcastController {
  mediaserver._snapcastExtraSources = remotePipeSources;
  mediaserver._snapcastExtraMetaNames = remoteStreamNames;

  systemd.services = services;
}
