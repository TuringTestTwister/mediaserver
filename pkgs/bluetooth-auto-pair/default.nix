{ pkgs, makeWrapper, ... }:
let
  runtime-paths = with pkgs; lib.makeBinPath [
    bluez
    gobject-introspection
  ];
  bluetooth-simple-agent = pkgs.stdenv.mkDerivation rec {
    name = "bluetooth-simple-agent";

    dontUnpack = true;

    nativeBuildInputs = with pkgs; [
      gobject-introspection
      makeWrapper
      wrapGAppsHook
    ];

    buildInputs = with pkgs; [
      gobject-introspection
      gtk3
      (pkgs.python3.withPackages (python-pkgs: with python-pkgs; [
        dbus-python
        gst-python
        pygobject3
      ]))
    ];

    propagatedBuildInputs = with pkgs; [
      gobject-introspection
      gtk3
      (pkgs.python3.withPackages (python-pkgs: with python-pkgs; [
        dbus-python
        gst-python
        pygobject3
      ]))
    ];

    installPhase = ''
      install -Dm755 ${./simple-agent.py} $out/bin/bluetooth-simple-agent

      wrapProgram $out/bin/bluetooth-simple-agent \
        --suffix PATH : ${runtime-paths}
    '';
  };
  run-script = pkgs.writeShellScriptBin "run-script" ''
    bluetoothctl <<EOF
    discoverable on
    pairable on
    EOF

    ${bluetooth-simple-agent}/bin/bluetooth-simple-agent -c NoInputNoOutput
  '';
in
pkgs.stdenv.mkDerivation {
  name = "bluetooth-auto-pair";

  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  installPhase = ''
    install -Dm755 ${run-script}/bin/run-script $out/bin/bluetooth-auto-pair

    wrapProgram $out/bin/bluetooth-auto-pair \
      --suffix PATH : ${runtime-paths}
  '';
}
