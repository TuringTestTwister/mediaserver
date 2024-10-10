{ ... }:
{
  hostName = "mediaserver";
  username = "mediaserver";
  ## Replace with personal SSH public key
  sshKeys = [
    # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNvmGn1/uFnfgnv5qsec0GC04LeVB1Qy/G7WivvvUZVBBDzp8goe1DsE8M8iqnBSin56gQZDWsd50co2MbFAWuqH2HxY7OGay7P/V2q+SziTYFva85WGl84qWvYMmdB+alAFBT3L4eH5cegC5NhNp+OGsQuq32RdojgXXQt6vyZnaOypuz90k3rqV6Rt+iBTLz6VziasCLcYydwOvi9f1q6YQwGPLKaupDrV6gxvoX9bXLdopqwnXPSE/Eqczxgwc3PefvAJPSd6TOqIXvbtpv/B3Elt5SPe2gq+qAsc5K0tzgra8KAe81Kkkpq4FuKJzHbT+EmO70wiJjru7zMEhd person@hostname"
  ];
  ## Generate with:
  ##   mkpasswd -m sha-512
  hashedPassword = "<replace me>";
  wifiSSID = "<replace me>";
  wifiPassword = "<replace me>";
  snapcastLatency = "0";
  snapcastServerHost = "::1";
  controller = false;
  # move-sink-input is disabled, so if a client was started with the wrong sink, it will stick across restarts
  # This setting will force it to use the headphone output.
  # To fix it so this setting is not needed:
  #   systemctl stop pulseaudio
  #   sudo rm -rf /var/lib/pulse
  #   systemctl start pulseaudio
  # See: https://unix.stackexchange.com/questions/525070/pulseaudio-not-using-default-sink
  forceHeadphoneOutput = false;
}
