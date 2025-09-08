{ config, lib, pkgs, ... }:

{
  boot = {
    loader = {
      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      generic-extlinux-compatible.enable = true;
    };

    kernelPackages = pkgs.linuxPackages_rpi4;
  };

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  powerManagement.cpuFreqGovernor = "ondemand";

  # Deals with compilation error
  # https://github.com/NixOS/nixpkgs/issues/154163
  nixpkgs = {
    overlays = [
      (final: super: {
        makeModulesClosure = x:
          super.makeModulesClosure (x // { allowMissing = true; });
      })
    ];
  };
}
