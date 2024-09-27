{ lib, pkgs, hostParams, ... }:
{
  systemd.services.bluetooth-auto-pair = {
    wantedBy = [
      "bluetooth.service"
    ];
    after = [
      "bluetooth.service"
    ];
    bindsTo = [
      "bluetooth.service"
    ];
    path = with pkgs; [
      bluez
    ];
    script = ''
      # SEE: https://raspberrypi.stackexchange.com/questions/50496/automatically-accept-bluetooth-pairings

      ## @TODO: None of these work completely. Method 2 seems to allow pairing, but audio doesn't work

      # Method 1
      bluetoothctl <<EOF
      power on
      discoverable on
      pairable on
      agent NoInputNoOutput
      default-agent 
      EOF

      # Method 2
      btmgmt power off
      btmgmt discov on
      btmgmt connectable on
      btmgmt pairable on
      btmgmt power on
      btmgmt io-cap 3   # 3 is agent NoInputNoOutput

      # Method 3
      hciconfig hci0 piscan 
      hciconfig hci0 sspmode 1
    '';
  };
}
