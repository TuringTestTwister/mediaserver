{ lib, pkgs, hostParams, ... }:
{
  # @TODO: make list of hosts configured from hostParams
  services.snapserver = {
    streams = {
      a_main.location = lib.mkForce "/b_bluetooth/d_mediaserver/e_speakerserver/f_x1c/g_antikythera/c_spotify";
      # mediaserver = {
      #   type = "pipe";
      #   location = "/run/snapserver/partymusic";
      #   query = {
      #     mode = "create";
      #     dryout_ms = "2000";
      #     send_silence = "false";
      #     idle_threshold = "5000";
      #     silence_threshold_percent = "1.0";
      #   };
      # };
      d_mediaserver = {
        type = "pipe";
        location = "/run/snapserver/mediaserver";
        query = {
          mode = "create";
          dryout_ms = "2000";
          send_silence = "false";
          idle_threshold = "5000";
          silence_threshold_percent = "1.0";
        };
      };
      e_speakerserver = {
        type = "pipe";
        location = "/run/snapserver/speakerserver";
        query = {
          mode = "create";
          dryout_ms = "2000";
          send_silence = "false";
          idle_threshold = "5000";
          silence_threshold_percent = "1.0";
        };
      };
      f_x1c = {
        type = "pipe";
        location = "/run/snapserver/x1c";
        query = {
          mode = "create";
          dryout_ms = "2000";
          send_silence = "false";
          idle_threshold = "5000";
          silence_threshold_percent = "1.0";
        };
      };
      g_antikythera = {
        type = "pipe";
        location = "/run/snapserver/antikythera";
        query = {
          mode = "create";
          dryout_ms = "2000";
          send_silence = "false";
          idle_threshold = "5000";
          silence_threshold_percent = "1.0";
        };
      };
    };
  };

  # systemd.services.snapclient-partymusic = {
  #   wantedBy = [
  #     "pulseaudio.service"
  #   ];
  #   after = [
  #     "pulseaudio.service"
  #   ];
  #   path = with pkgs; [
  #     pulseaudio
  #     snapcast
  #   ];
  #   script = ''
  #     # @TODO: try this with hostname instead, or do a lookup before running
  #     snapclient --logsink null --instance 2 -h 10.0.0.29 --player file > /run/snapserver/partymusic
  #   '';
  #   serviceConfig = {
  #     User = hostParams.username;
  #   };
  # };

  systemd.services.snapclient-mediaserver = {
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
      snapclient --logsink null --instance 3 -h 10.0.0.32 --player file > /run/snapserver/mediaserver
    '';
    serviceConfig = {
      User = hostParams.username;
    };
  };

  systemd.services.snapclient-speakerserver = {
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
      snapclient --logsink null --instance 4 -h 10.0.0.28 --player file > /run/snapserver/speakerserver
    '';
    serviceConfig = {
      User = hostParams.username;
    };
  };

  systemd.services.snapclient-x1c = {
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
      snapclient --logsink null --instance 4 -h 10.0.0.28 --player file > /run/snapserver/x1c
    '';
    serviceConfig = {
      User = hostParams.username;
    };
  };

  systemd.services.snapclient-antikythera = {
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
      snapclient --logsink null --instance 4 -h 10.0.0.28 --player file > /run/snapserver/antikythera
    '';
    serviceConfig = {
      User = hostParams.username;
    };
  };
}
