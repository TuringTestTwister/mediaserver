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

    # Helper function to create script apps
    mkScriptApp = system: pkgs: scriptName: scriptPath: {
      type = "app";
      program = "${pkgs.writeShellScriptBin scriptName ''
        exec ${scriptPath} "$@"
      ''}/bin/${scriptName}";
    };

    # Create apps for a specific system
    mkSystemApps = system: pkgs: {
      deploy = mkScriptApp system pkgs "deploy" ./scripts/remote-deploy.sh;
      build-image = mkScriptApp system pkgs "build-image" ./scripts/build-image.sh;
      flash = mkScriptApp system pkgs "flash" ./scripts/flash.sh;
      build = mkScriptApp system pkgs "build" ./scripts/build.sh;
      run = mkScriptApp system pkgs "run" ./scripts/run.sh;
      setup = mkScriptApp system pkgs "setup" ./scripts/setup.sh;
    };
  in
  {
    # Expose scripts as flake apps
    apps = {
      x86_64-linux = mkSystemApps "x86_64-linux" nixpkgs.legacyPackages.x86_64-linux;
      aarch64-linux = mkSystemApps "aarch64-linux" nixpkgs.legacyPackages.aarch64-linux;
    };

    nixosConfigurations = {
      rpi4 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ## Needed to build sd images
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
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
          ## Needed to build sd images
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
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
