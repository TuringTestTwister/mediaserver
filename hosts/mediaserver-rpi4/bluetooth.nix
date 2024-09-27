{ lib, pkgs, hostParams, ... }:
{
  environment.systemPackages = with pkgs; [
    bluez-alsa
  ];

  hardware.bluetooth = {
    enable = true;

    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Class = "0x0041C";
      };
    };
  };

  services.blueman.enable = true;

  imports = [
    # ./bluetooth-auto-pair.nix
  ];
}
