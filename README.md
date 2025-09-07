README
======

Raspberry Pi Media Server

Currently only supports Spotify Connect.

### Setup for non-NixOS operating systems

This has only been tested on a NixOS host. Running `make setup` should get Nix installed on Fedora,
but it still needs to be manually configured as per "Dev Environment Setup" below. Refer to the Nix
home page on how to install Nix on distributions other than Fedora.

### Nix Environment Setup

Must have the following in your host nix config to cross compile:

```
{
  # Enable binfmt emulation of aarch64-linux.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
```

The following will help build speeds:


```
{
  nix = {
    settings = {
      substituters = [
        "https://arm.cachix.org/"
      ];
      trusted-public-keys = [
        "arm.cachix.org-1:5BZ2kjoL1q6nWhlnrbAl+G7ThY7+HaBRD9PZzqZkbnM="
      ];
    };
  };
}
```

### Configuring

Edit `host-params.nix`

### Building

Building will generate two images, an ARM rasberry pi image, and an x86 VM image.
Be aware that building can take a long time, even hours, on slow machines, as
it's building the ARM image in a qemu VM.

```
make build-image
```

### Flashing

Replace `/dev/sda` with your SD card device

```
make flash DEVICE=/dev/sda
```

### Running x86 version in local VM

```
make run
```

### SSH'ing into local VM

```
make ssh
```

### Rebuilding config on raspberry pi or VM

Once the machine is running, you can edit Nix config and build without generating images.
This is much faster and good for making changes. When running a VM, the ~/nixcfg path
is shared with the host, so you can commit your changes to git.

```
cd ~/nixcfg
make build
```

### Connecting to wifi from raspberry pi

Edit `host-params.nix` to enter wifi credentials before building. You can also
manually connect to other networks after ssh'ing into the mediaserver.

```
sudo nmcli dev wifi connect <network-ssid> --ask
sudo nmcli device set wlan0 autoconnect yes
```

### Connecting bluetooth input (e.g. phone or computer)

```
bluetoothctl
  power on
  discoverable on
  pairable on
  # pair from phone
  # answer yes to everything on phone and mediaserver
  trust
```

### Connecting bluetooth output (e.g. speaker)

```
bluetoothctl
  power on
  discoverable on
  pairable on
  scan on
  pair <speaker address>
  # May need to tap bluetooth button on speaker, e.g. Soundcore Boom 2
  connect
  trust
```

### Seeing what the config.txt firmware file will be before rebuilding

```
nix build '.#nixosConfigurations.mediaserver-rpi4.config.hardware.raspberry-pi.config-output'
nix eval '.#nixosConfigurations.mediaserver-rpi4.config.hardware.raspberry-pi.config-output' --raw
```
