# NixOS Media Server

A NixOS-based media server configuration for Raspberry Pi and x86 systems, featuring Snapcast multi-room audio, Spotify Connect, Mopidy, and Bluetooth audio support.

## Features

- **Multi-room audio** with Snapcast (synchronized audio across multiple devices)
- **Spotify Connect** support via librespot
- **Mopidy** music server with web interface
- **Bluetooth** audio support with auto-pairing
- **Network audio** streaming capabilities
- **PulseAudio** integration
- **Web UI** for Snapcast control

## Quick Start

### 1. Prerequisites

Install Nix and required dependencies:

```bash
# From the mediaserver directory
./scripts/setup.sh
```

### 2. Create Your Configuration

Create a new directory for your configuration with just two files:

**flake.nix:**
```nix
{
  inputs = {
    mediaserver.url = "github:turingtesttwister/mediaserver";
    # Or for local development:
    # mediaserver.url = "path:/path/to/mediaserver";
  };

  outputs = { mediaserver, ... }:
  let
    sharedConfig = {
      username = "mediaserver";
      sshKeys = [
        "ssh-rsa YOUR_SSH_KEY_HERE"
      ];
      hashedPassword = "$6$..."; # Generate with: mkpasswd -m sha-512
      wifiSSID = "your-wifi-network";
      snapcastServerHost = "mediaserver.lan";
    };
  in
  {
    nixosConfigurations = {
      my-mediaserver = mediaserver.nixosConfigurations.rpi4.extendModules {
        modules = [{
          mediaserver = sharedConfig // {
            hostname = "my-mediaserver";
          };
        }];
      };
    };
  };
}
```

**wireless-secrets** (optional, for WiFi, no quotes around password):
```bash
password=your-wifi-password
```

### 3. Build and Deploy

From your configuration directory containing the flake.nix:

#### Building Images

```bash
# Clone or get the mediaserver repo
git clone https://github.com/turingtesttwister/mediaserver

# Build SD card image from your config directory
cd my-config
../mediaserver/scripts/build-image.sh -f . my-mediaserver

# Or using nix directly (no clone needed)
nix run github:turingtesttwister/mediaserver#build-image -- -f . my-mediaserver
```

#### Flashing to SD Card

```bash
# Flash the built image to an SD card (from your config directory)
../mediaserver/scripts/flash.sh -f . /dev/sda

# Or using nix directly
nix run github:turingtesttwister/mediaserver#flash -- -f . /dev/sda
```

#### Remote Deployment

```bash
# Deploy to an existing NixOS system (from your config directory)
../mediaserver/scripts/remote-deploy.sh -f . -u mediaserver hostname.lan my-mediaserver

# Or using nix directly
nix run github:turingtesttwister/mediaserver#deploy -- -f . -u mediaserver hostname.lan my-mediaserver
```

## Scripts

All deployment scripts are located in the `scripts/` directory and can be used with external flake configurations:

### `setup.sh`
Installs Nix and required system dependencies.

```bash
./scripts/setup.sh [--check]
```

### `build-image.sh`
Builds NixOS images for Raspberry Pi or x86 systems.

```bash
./scripts/build-image.sh -f /path/to/your-flake [config-name]
```

Options:
- `-f, --flake-dir`: Path to your flake directory (default: current directory)
- `-o, --output-dir`: Output directory for built images
- `-k, --keep-compressed`: Keep compressed .zst files

### `flash.sh`
Writes a built image to an SD card or USB device.

```bash
./scripts/flash.sh -f /path/to/your-flake /dev/sda
```

Options:
- `-f, --flake-dir`: Path to your flake directory
- `-c, --config`: Specific configuration to flash
- `-i, --image`: Specific image file to flash
- `-y, --yes`: Skip confirmation prompt

### `remote-deploy.sh`
Deploys a NixOS configuration to a remote host by building locally and copying the closure.

```bash
./scripts/remote-deploy.sh -f /path/to/your-flake -u user hostname config-name
```

Options:
- `-f, --flake-dir`: Path to your flake directory
- `-u, --user`: Remote user (default: root)
- `-d, --dry-run`: Show what would be done
- `-r, --reboot`: Reboot after activation

### `build.sh`
Rebuilds NixOS configuration locally (for use on NixOS systems).

```bash
./scripts/build.sh -f /path/to/your-flake [config-name]
```

### `run.sh`
Runs an x86 VM image locally for testing.

```bash
./scripts/run.sh -f /path/to/your-flake
```

Options:
- `-m, --memory`: VM memory size (default: 8G)
- `-s, --smp`: Number of CPUs (default: 4)

## Configuration Options

The mediaserver module accepts the following options:

```nix
{
  mediaserver = {
    # Basic settings
    hostname = "mediaserver";           # System hostname
    username = "mediaserver";           # Admin user
    timeZone = "America/Los_Angeles";  # Timezone

    # Authentication
    sshKeys = [ "ssh-rsa ..." ];       # SSH public keys
    hashedPassword = "$6$...";         # User password hash

    # Network
    wifiSSID = "network-name";          # WiFi network name

    # Snapcast
    snapcastLatency = 0;                # Audio latency in ms
    snapcastServerHost = "server.lan";  # Snapcast server address
    snapcastController = false;         # Enable controller mode
    snapcastControllerStreams = [       # Controller streams config
      {
        name = "stream1";
        ip-address = "10.0.0.10";
      }
    ];

    # Audio
    forceHeadphoneOutput = false;       # Force headphone output
  };
}
```

## Multi-room Audio Setup

To set up a multi-room audio system:

1. **Configure a Controller Node**: Set `snapcastController = true` on one device
2. **Configure Client Nodes**: Point `snapcastServerHost` to the controller
3. **Add Streams**: Configure `snapcastControllerStreams` on the controller

Example controller configuration:

```nix
{
  mediaserver = {
    hostname = "audio-controller";
    snapcastController = true;
    snapcastControllerStreams = [
      { name = "living-room"; ip-address = "10.0.0.10"; }
      { name = "kitchen"; ip-address = "10.0.0.11"; }
      { name = "bedroom"; ip-address = "10.0.0.12"; }
    ];
  };
}
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
  connect <speaker address>
  trust
```


## Architecture

The project is structured as follows:

```
mediaserver/
├── flake.nix              # Main flake definition
├── module.nix             # NixOS module options
├── configuration.nix      # Base configuration
├── rpi4.nix              # Raspberry Pi 4 specific config
├── x86.nix               # x86 specific config
├── scripts/              # Deployment scripts
│   ├── setup.sh
│   ├── build-image.sh
│   ├── flash.sh
│   ├── remote-deploy.sh
│   ├── build.sh
│   └── run.sh
├── profiles/             # Service configurations
│   ├── snapcast.nix
│   ├── mopidy.nix
│   └── ...
└── mediaserver-rpi4/     # Hardware-specific configs
    ├── bluetooth.nix
    ├── sound.nix
    └── ...
```

## Wireless Secrets

For WiFi configuration, create a `wireless-secrets` file in your configuration directory:

```bash
password=your-wifi-password
```

This file will be deployed to `/etc/nixos/wireless-secrets` on the target system.

## Troubleshooting

### SSH Access
Default SSH port is 22. After deployment, you can access the system:
```bash
ssh mediaserver@hostname.lan
```

### Audio Issues
- Check PulseAudio status: `systemctl status pulseaudio`
- View Snapcast logs: `journalctl -u snapserver` or `journalctl -u snapclient`
- Reset audio configuration: Stop PulseAudio, remove `/var/lib/pulse`, restart

### Network Issues
- Verify WiFi credentials in `wireless-secrets`
- Check network status: `networkctl status`
- View network logs: `journalctl -u NetworkManager`

### Bluetooth speaker issues
- Test for glitches:

```bash
pactl load-module module-sine frequency=440 rate=48000 sink=bluez_sink.<DEVICE_MAC_ADDRESS>.a2dp_sink
pactl unload-module module-sine

```

## License

[Add your license here]

## Contributing

[Add contribution guidelines]

