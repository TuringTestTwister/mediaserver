{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      librespot = (prev.librespot.override {
        withAvahi = true;
        withDNS-SD = true;
        withMDNS = true;
      }).overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [
          ../patches/librespot-discovery.patch
        ];
      });
    })
  ];
}
