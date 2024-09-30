{ pkgs, ... }:

{
  hardware.pulseaudio = {
    enable = true;
    # Add out-of-tree support for AAC, APTX, APTX-HD and LDAC
    package = pkgs.pulseaudioFull;
    systemWide = true;
    support32Bit = true;
    ## @TODO: move to snapcast profile?
    extraConfig = ''
      # Don't switch sources on detection
      unload-module module-switch-on-port-available
    '';
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
