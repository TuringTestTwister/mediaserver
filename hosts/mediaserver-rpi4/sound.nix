{ pkgs, ... }:

{
  imports = [
    ./bluetooth.nix
  ];

  sound.enable = true;

  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
    support32Bit = true;
  };

  boot.loader.raspberryPi.firmwareConfig = ''
    dtparam=audio=on
  '';
}
