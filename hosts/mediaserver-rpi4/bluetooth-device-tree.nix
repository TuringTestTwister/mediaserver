{ lib, pkgs, hostParams, ... }:
{
  #-------------------------------------------------------------------------------
  # See: https://github.com/NixOS/nixpkgs/issues/123725#issuecomment-1613705556
  #-------------------------------------------------------------------------------

  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = lib.mkDefault true;
  # doesn't work for the CM module, so we exclude e.g. bcm2835-rpi-cm4.dts
  hardware.deviceTree.filter = "bcm2711-rpi-4*.dtb";
  hardware.deviceTree = {
    overlays = [
      {
        name = "bluetooth-overlay";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
              compatible = "brcm,bcm2711";

              fragment@0 {
                  target = <&uart0_pins>;
                  __overlay__ {
                          brcm,pins = <30 31 32 33>;
                          brcm,pull = <2 0 0 2>;
                  };
              };
          };
        '';
      }
    ];
  };
}
