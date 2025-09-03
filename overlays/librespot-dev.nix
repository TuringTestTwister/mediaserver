{ ... }:
{
   nixpkgs.overlays = [
     (final: prev: {

       librespot = final.callPackage prev.librespot.override {
         ## No longer supported
         # withMDNS = false;

         rustPlatform = final.rustPlatform // {
           buildRustPackage = args: final.rustPlatform.buildRustPackage (args // rec {
             ## dev branch which addresses issue with 500 errors
             # https://github.com/librespot-org/librespot/issues/1527
             version = "v0.7.1";
             src = final.fetchFromGitHub {
               owner = "librespot-org";
               repo = "librespot";
               rev = "${version}";
               hash = "sha256-gBMzvQxmy+GYzrOKWmbhl56j49BK8W8NYO2RrvS4mWI=";
             };
             buildFeatures = (args.buildFeatures or []) ++ [ "native-tls" ];
             cargoHash = "sha256-PiGIxMIA/RL+YkpG1f46zyAO5anx9Ii+anKrANCM+rk=";
           });
         };
       };
     })
   ];
}

