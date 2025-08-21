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
             version = "78ce118d32912adfb2705481f69c83df6a88211f";
             src = final.fetchFromGitHub {
               owner = "librespot-org";
               repo = "librespot";
               rev = "v${version}";
               # sha256 = "sha256-/YMICsrUMYqiL5jMlb5BbZPlHfL9btbWiv/Kt2xhRW4=";
               hash = "sha256-4psjwp2y70yf81wuENPXfSnsYCbNKbDM/pPWZbW3WBU=";
             };
             buildFeatures = (args.buildFeatures or []) ++ [ "native-tls" ];
             cargoHash = "sha256-6y/KE19eqUNcn23v/w0GBDa5Sivn1P0ZgPGLdYRreLg=";
           });
         };
       };
     })
   ];
}

