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
    mediaserver-inputs = inputs;
  in
  {
    nixosConfigurations = {
      rpi4 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./rpi4.nix
        ];
        specialArgs = {
          system = "aarch64-linux";
          inherit mediaserver-inputs;
        };
      };
      rpi4-cross-compile = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./rpi4.nix
          { nixpkgs.buildPlatform = "x86_64-linux"; }
        ];
        specialArgs = {
          system = "aarch64-linux";
          inherit mediaserver-inputs;
        };
      };
      x86 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./x86.nix
        ];
        specialArgs = {
          system = "x86_64-linux";
          inherit mediaserver-inputs;
        };
      };
    };
  };
}
