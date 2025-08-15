{ lib, pkgs, hostParams, ... }:
{
  # @TODO: make list of hosts configured from hostParams
  services.snapserver = {
    streams = {
      a_main.location = lib.mkForce "/b_bluetooth/d_mediaserver/e_speakerserver/f_p16/g_antikythera/g_work_dock/c_spotify";
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
      f_p16 = {
        type = "pipe";
        location = "/run/snapserver/p16";
        query = {
          mode = "create";
          dryout_ms = "2000";
          send_silence = "false";
          idle_threshold = "5000";
          silence_threshold_percent = "1.0";
        };
      };
      g_work_dock = {
        type = "pipe";
        location = "/run/snapserver/work_dock";
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

  systemd.services.snapclient-p16 = {
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
      snapclient --logsink null --instance 5 -h 10.0.0.62 --player file > /run/snapserver/p16
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
      snapclient --logsink null --instance 6 -h 10.0.0.59 --player file > /run/snapserver/antikythera
    '';
    serviceConfig = {
      User = hostParams.username;
    };
  };

  systemd.services.snapclient-work-dock = {
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
      snapclient --logsink null --instance 7 -h 10.0.0.45 --player file > /run/snapserver/work_dock
    '';
    serviceConfig = {
      User = hostParams.username;
    };
  };
}
