{
  description = "Media Server";

  inputs = {
    ## Bluetooth doesn't currently work on stable
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Trails trunk - latest packages with broken commits filtered out
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Very latest packages - some commits broken
    nixpkgs-trunk.url = "github:NixOS/nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim-config.url = "git+https://git.homefree.host/homefree/nixvim-config";

    nix-editor.url = "github:vlinkz/nix-editor";

    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.01.tar.bz2";
    };
    rpi-linux-6_1-src = {
      flake = false;
      url = "github:raspberrypi/linux/stable_20231123";
    };
    rpi-firmware-src = {
      flake = false;
      url = "github:raspberrypi/firmware/7e6decce72fdff51923e9203db46716835ae889a";
    };
    rpi-firmware-nonfree-src = {
      flake = false;
      url = "github:RPi-Distro/firmware-nonfree/88aa085bfa1a4650e1ccd88896f8343c22a24055";
    };
    rpi-bluez-firmware-src = {
      flake = false;
      url = "github:RPi-Distro/bluez-firmware/d9d4741caba7314d6500f588b1eaa5ab387a4ff5";
    };
  };

  outputs = {
    self,
    nixos-generators,
    nixos-hardware,
    nixpkgs,
    ...
  }@inputs:
  let
    hostParams = import ./host-params.nix {};
  in
  {
    nixosConfigurations = {
      # mediaserver-rpi4 =
      # let
      #   system = "aarch64-linux";
      # in
      # nixos-generators.nixosGenerate {
      #   system = system;
      #   modules = [
      #     nixos-hardware.nixosModules.raspberry-pi-4
      #     ./configuration.nix
      #     ./hosts/mediaserver-rpi4/hardware-configuration.nix
      #     ./hosts/mediaserver-rpi4/boot.nix
      #     ./hosts/mediaserver-rpi4/bluetooth.nix
      #     ./hosts/mediaserver-rpi4/sound.nix
      #   ];
      #   format = "sd-aarch64";
      #   specialArgs = {
      #     inherit inputs;
      #     inherit system;
      #   };
      # };
      mediaserver-rpi4 =
      let
        system = "aarch64-linux";
      in
      inputs.nixpkgs.lib.nixosSystem {
        system = system;
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          ./configuration.nix
          ./hosts/mediaserver-rpi4/hardware-configuration.nix
          ./hosts/mediaserver-rpi4/boot.nix
          ./hosts/mediaserver-rpi4/bluetooth.nix
          ./hosts/mediaserver-rpi4/sound.nix
          inputs.nixvim-config.nixosModules.default
          {
            nixvim-config.enable = true;
            nixvim-config.enable-ai = false;
            nixvim-config.enable-startify-cowsay = false;
          }
        ];
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit hostParams;
        };
      };
      mediaserver-x86 =
      let
        system = "x86_64-linux";
      in
      inputs.nixpkgs.lib.nixosSystem {
        system = system;
        modules = [
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          ./configuration.nix
          ./profiles/hardware-configuration.nix
          ./profiles/virtual-machine.nix
        ];
        specialArgs = {
          inherit inputs;
          inherit system;
          inherit hostParams;
        };
      };
    };
  };
}
