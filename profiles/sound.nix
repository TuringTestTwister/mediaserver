{ config, pkgs, inputs, system, hostParams, ...}:
{
  environment.systemPackages = with pkgs; [
    ncpamixer
    pamix
  ];
}
