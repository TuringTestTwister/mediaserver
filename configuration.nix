{ inputs, hostParams, pkgs, ... }:

{
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
    # ./modules/network-manager-wireless.nix
    ./profiles/common.nix
    ./profiles/mopidy.nix
    ./profiles/snapcast.nix
    ./profiles/sound.nix
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
      enable = false;
    };
    wireless = {
      # wpa_supplicant
      enable = true;
      # Used by modules/network-manager-wireless.nix
      networks = {
        ${hostParams.wifiSSID} = {
          psk = hostParams.wifiPassword;
	  extraConfig = ''
            freq_list=5170 5180 5190 5200 5210 5220 5230 5240 5260 5280 5300 5320 5500 5520 5540 5560 5580 5600 5620 5640 5660 5680 5700 5720 5745 5765 5785 5805 5825
	  '';
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


