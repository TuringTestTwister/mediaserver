{
  description = "Media Server";

  inputs = {
    # Use stable for main
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    # Trails trunk - latest packages with broken commits filtered out
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Very latest packages - some commits broken
    nixpkgs-trunk.url = "github:NixOS/nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-editor.url = "github:vlinkz/nix-editor";
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
      #     (import ./configuration.nix)
      #     (import ./hosts/mediaserver-rpi4/hardware-configuration.nix)
      #     (import ./hosts/mediaserver-rpi4/boot.nix)
      #     (import ./hosts/mediaserver-rpi4/sound.nix)
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
          (import ./configuration.nix)
          (import ./hosts/mediaserver-rpi4/hardware-configuration.nix)
          (import ./hosts/mediaserver-rpi4/boot.nix)
          (import ./hosts/mediaserver-rpi4/sound.nix)
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
          (import ./configuration.nix)
          (import ./profiles/hardware-configuration.nix)
          (import ./profiles/virtual-machine.nix)
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
