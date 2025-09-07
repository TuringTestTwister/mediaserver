
{ ... }:
{
  imports = [
    ./rpi4.nix
  ];

  nixpkgs.buildPlatform = "x86_64-linux";
}
