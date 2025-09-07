{ pkgs, ...}:
{
  environment.systemPackages = with pkgs; [
    ncpamixer
    pamix
    pulsemixer
  ];
}
