{ lib, pkgs, hostParams, ... }:
{
  imports = [
    ./bluetooth-auto-pair.nix
  ];

  environment.systemPackages = with pkgs; [
    bluez-alsa
  ];

  hardware.bluetooth = {
    enable = true;

    powerOnBoot = true;

    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Class = "0x0041C";
        Experimental = true; # Show battery charge of Bluetooth devices
      };
    };
  };

  services.blueman.enable = true;
}
