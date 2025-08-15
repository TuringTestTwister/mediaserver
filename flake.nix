{
  description = "Media Server";

  inputs = {
    ## Bluetooth doesn't currently work on stable
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Trails trunk - latest packages with broken commits filtered out
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Very latest packages - some commits broken
    nixpkgs-trunk.url = "github:NixOS/nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixvim-config.url = "git+https://git.homefree.host/homefree/nixvim-config";
  };

  outputs = {
    self,
    nixos-hardware,
    nixpkgs,
    ...
  }@inputs:
  let
    hostParams = import ./host-params.nix {};
    raspi-modules = [
      "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      # nixos-hardware.nixosModules.raspberry-pi-4
      ./configuration.nix
      ./hosts/mediaserver-rpi4/hardware-configuration.nix
      ./hosts/mediaserver-rpi4/sound.nix

      #j @TODO: Identify nixvim performance bottlenecks
      # inputs.nixvim-config.nixosModules.default
      # {
      #   nixvim-config.enable = true;
      #   nixvim-config.enable-ai = false;
      #   nixvim-config.enable-startify-cowsay = false;
      # }
      {
        programs.neovim = {
          enable = true;
          defaultEditor = true;
        };
      }

      ## Are these still needed?
      # ./hosts/mediaserver-rpi4/boot.nix
      # ./hosts/mediaserver-rpi4/bluetooth.nix
    ];
  in
  {
    nixosConfigurations = {
      mediaserver-rpi4 = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = raspi-modules;
        specialArgs = {
          system = "aarch64-linux";
          inherit inputs;
          inherit hostParams;
        };
      };
      mediaserver-rpi4-build = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        ## Add buildPlatform to cross-compile rather than use binfmt with qemu
        modules = raspi-modules ++ [
          { nixpkgs.buildPlatform = "x86_64-linux"; }
        ];
        specialArgs = {
          system = "aarch64-linux";
          inherit inputs;
          inherit hostParams;
        };
      };
      mediaserver-x86 = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          ./configuration.nix
          ./profiles/hardware-configuration.nix
          ./profiles/virtual-machine.nix
        ];
        specialArgs = {
          inherit inputs;
          system = "x86_64-linux";
          inherit hostParams;
        };
      };
    };
  };
}
