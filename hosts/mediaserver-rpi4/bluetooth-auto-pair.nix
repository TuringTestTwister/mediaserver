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
}
