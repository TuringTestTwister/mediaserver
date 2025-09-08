{ mediaserver-inputs, ...}:
{
  imports = [
    ./configuration.nix

    mediaserver-inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./mediaserver-rpi4/bluetooth.nix
    ./mediaserver-rpi4/boot.nix
    ./mediaserver-rpi4/hardware-configuration.nix
    ./mediaserver-rpi4/sound.nix
  ];

}
