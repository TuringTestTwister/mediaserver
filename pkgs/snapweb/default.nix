{ stdenv, fetchurl, unzip }:

let
  name = "snapweb";
in
stdenv.mkDerivation rec {
  pname = name;
  version = "v0.8.0";

  src = fetchurl {
    url = "https://github.com/badaix/snapweb/releases/download/${version}/snapweb.zip";
    sha256 = "0p56q81qri6nbl8sxw89mrlhlhi8smb18jgngcf8hi3yv2a8y1vi";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    unzip
  ];

  installPhase = ''
    cd ..
    mkdir -p $out/share/html
    cd $out/share/html
    unzip $src
  '';
}

