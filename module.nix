{ lib, ... }:

{
  options.mediaserver = {
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "mediaserver";
      description = "Hostname for the system";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "mediaserver";
      description = "Admin username for the system";
    };

    ## @TODO: Detect or have user enter during setup
    timeZone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Timezone for the system in tz database format.
        See: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

        example: America/Los_Angeles
      '';
    };

    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH keys for username pubkey ssh auth";
    };

    hashedPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Password for username.
        Generate with:
          mkpasswd -m sha-512
      '';
    };

    wifiSSID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Wifi access point name";
    };

    wifiPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Wifi password";
    };

    snapcastLatency = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "latency in milliseconds";
    };

    snapcastServerHost = lib.mkOption {
      type = lib.types.string;
      default = "::1";
      description = "Snapcast server host address";
    };

    snapcastController = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable to make central audio hub.";
    };

    snapcastControllerStreams = lib.mkOption {
      description = "Enable to make central audio hub.";
      default = [];
      type = with lib.types; listOf (submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.string;
            description = "Name of stream";
          };

          ip-address = lib.mkOption {
            type = lib.types.string;
            description = "IP Address of stream";
          };
        };
      });
    };

    forceHeadphoneOutput = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "
        Force output on headphone port

        move-sink-input is disabled, so if a client was started with the wrong sink, it will stick across restarts
        This setting will force it to use the headphone output.
        To fix it so this setting is not needed:
          systemctl stop pulseaudio
          sudo rm -rf /var/lib/pulse
          systemctl start pulseaudio
        See: https://unix.stackexchange.com/questions/525070/pulseaudio-not-using-default-sink
      ";
    };
  };
}
