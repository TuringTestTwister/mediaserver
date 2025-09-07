{ pkgs, ... }:

{
  services.pulseaudio = {
    enable = true;
    # Add out-of-tree support for AAC, APTX, APTX-HD and LDAC
    package = pkgs.pulseaudioFull;
    systemWide = true;
    support32Bit = true;
  };

  # services.pipewire = {
  #   enable = true;
  #   systemWide = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  #   # jack.enable = true;
  # };
}
