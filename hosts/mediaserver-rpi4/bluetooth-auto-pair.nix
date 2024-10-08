{ lib, pkgs, hostParams, ... }:
let
  bluetooth-auto-pair = pkgs.callPackage ../../pkgs/bluetooth-auto-pair {};
in
{
  environment.systemPackages = with pkgs; [
    bluetooth-auto-pair
  ];

  systemd.services.bluetooth-auto-pair = {
    wantedBy = [
      "bluetooth.service"
    ];
    after = [
      "bluetooth.service"
    ];
    bindsTo = [
      "bluetooth.service"
    ];
    script = ''
      ${bluetooth-auto-pair}/bin/bluetooth-auto-pair
    '';
  };

  hardware.bluetooth = {
    settings = {
      General = {
        # Pairing always on
        AlwaysPairable = "true";
        # Don't disable discoverability after timeout
	DiscoverableTimeout = "0";
	# Faster but uses more power
	FastConnectable = "true";
	# Allow repairing of existing devices
	JustWorksRepairing = "always";
      };
    };
  };
}
