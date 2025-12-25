{ config, lib, pkgs, ... }:
let
  # Build the meta source path: bluetooth/spotify/stream1/stream2/...
  remoteStreamNames = lib.lists.map (stream: stream.name) config.mediaserver.snapcastControllerStreams;
  main-location = "bluetooth/spotify" + (if remoteStreamNames == [] then "" else "/" + (lib.strings.concatStringsSep "/" remoteStreamNames));

  # Generate pipe source URIs for remote streams
  remotePipeSources = lib.lists.map (stream:
    "pipe:///run/snapserver/${stream.name}?name=${stream.name}&mode=create&dryout_ms=2000&send_silence=false&idle_threshold=5000&silence_threshold_percent=1.0"
  ) config.mediaserver.snapcastControllerStreams;

  # All sources when controller is enabled
  allSources = [
    "pipe:///run/snapserver/bluetooth?name=bluetooth"
    "pipe:///run/snapserver/spotify?name=spotify"
  ] ++ remotePipeSources ++ [
    "meta:///${main-location}?name=main"
  ];

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
    settings.stream.source = lib.mkForce allSources;
  } else {};

  systemd.services = if config.mediaserver.snapcastController then services else {};
}
