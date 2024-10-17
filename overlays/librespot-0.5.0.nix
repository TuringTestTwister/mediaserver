{ config, pkgs, lib, ... }:
{
   nixpkgs.overlays = [ 
     (final: prev: {

       librespot = final.callPackage prev.librespot.override {
         rustPlatform = final.rustPlatform // {
           buildRustPackage = args: final.rustPlatform.buildRustPackage (args // rec {
             version = "0.5.0";
             src = final.fetchFromGitHub {
               owner = "librespot-org";
               repo = "librespot";
               rev = "v${version}";
	       sha256 = "sha256-/YMICsrUMYqiL5jMlb5BbZPlHfL9btbWiv/Kt2xhRW4=";
             };
	     cargoHash = "sha256-UOvGvseWaEqqjuvTewDfkBeR730cKMQCq55weYmu15Y=";
           });
         };
       };
     }) 
   ];
}

