{ inputs, hostParams, pkgs, ... }:

{
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
    ./modules/network-manager-wireless.nix
    ./profiles/common.nix
    ./profiles/mopidy.nix
    ./profiles/snapcast.nix
    ./profiles/spotify-connect.nix
  ];

  # --------------------------------------------------------------------------------------
  # File system
  # --------------------------------------------------------------------------------------

  # @TODO: Setup luks or some disk encryption (ZFS?)

  # --------------------------------------------------------------------------------------
  # Network
  # --------------------------------------------------------------------------------------

  # Prevent hanging when waiting for network to be up
  systemd.network.wait-online.anyInterface = true;
  ## @TODO: Any ramifications of this?
  systemd.network.wait-online.enable = false;
  systemd.services.NetworkManager-wait-online.enable = false;

  # --------------------------------------------------------------------------------------
  # Device specific
  # --------------------------------------------------------------------------------------

  # @TODO: Make this UI configurable
  time.timeZone = "America/Los_Angeles";

  networking = {
    # @TODO: Make this UI configurable
    hostName = hostParams.hostName;
    useNetworkd = true;
    networkmanager = {
      enable = true;
    };
    wireless = {
      # disable wpa_supplicant
      enable = false;
      # Used by modules/network-manager-wireless.nix
      networks = {
        ${hostParams.wifiSSID} = {
          psk = hostParams.wifiPassword;
        };
      };
    };
  };

  # Supposedly fixes bluetooth stuttering by setting the appropriate region to limit frequencies, but doesn't seem to work
  environment.etc."default/crda" = {
    text = ''
      REGDOMAIN=US
    '';
  };

  # --------------------------------------------------------------------------------------
  # Hardware specific
  # --------------------------------------------------------------------------------------

  security.rtkit.enable = true;
}


