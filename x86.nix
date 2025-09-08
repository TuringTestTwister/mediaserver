{ mediaserver-inputs, ...}:
{
  imports = [
    ./configuration.nix

    mediaserver-inputs.nixos-hardware.nixosModules.common-cpu-intel
    mediaserver-inputs.nixos-hardware.nixosModules.common-pc-laptop
    ./profiles/hardware-configuration.nix
    ./profiles/virtual-machine.nix
  ];

}
