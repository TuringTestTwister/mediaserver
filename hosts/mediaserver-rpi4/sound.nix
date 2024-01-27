{ ... }:

{
  sound.enable = true;

  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
  };

  boot.loader.raspberryPi.firmwareConfig = ''
    dtparam=audio=on
  '';
}
