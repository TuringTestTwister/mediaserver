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
    nixosModules = rec {
      rpi4 = import ./default.nix {
        inherit mediaserver-inputs;
        system = "aarch64-linux";
      };
      default = rpi4;
      rpi4-cross-compile = import ./rpi4-cross-compile.nix {
        inherit mediaserver-inputs;
        system = "aarch64-linux";
      };
      mediaserver-x86 = import ./x86.nix {
        inherit mediaserver-inputs;
        system = "x86_64-linux";
      };
    };
  };
}
