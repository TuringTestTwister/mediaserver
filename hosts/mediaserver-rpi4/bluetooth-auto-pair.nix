{ lib, pkgs, hostParams, ... }:
{
  environment.systemPackages = with pkgs; [
    bluez-tools
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
    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        /bin/sh -c '${pkgs.coreutils}/bin/yes | ${pkgs.bluez-tools}/bin/bt-agent -c NoInputNoOutput'
      '';
      ExecStop = ''
        /bin/sh -c kill -s SIGINT $MAINPID
      '';
      Restart = "on-failure";
    };
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
