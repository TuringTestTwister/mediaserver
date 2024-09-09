{ config, pkgs, inputs, system, hostParams, ...}:
{

  # --------------------------------------------------------------------------------------
  # Base Nix config
  # --------------------------------------------------------------------------------------

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  # @TODO: Could this be useful for auto-upgrading systems out there?
  # system.autoUpgrade = {
  #   enable = true;
  #   allowReboot = true;
  #   flake = "github:TuringTestTwister/mediaserver";
  #   flags = [
  #     "--recreate-lock-file"
  #     "-no-write-lock-file"
  #     "-L" # print build logs
  #   ];
  #   dates = "daily";
  # };

  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" "nixos-config=/home/${hostParams.username}/nixcfg" ];

    # Which package collection to use system-wide.
    package = pkgs.nixFlakes;

    settings = {
      # sets up an isolated environment for each build process to improve reproducibility.
      # Disallow network callsoutside of fetch* and files outside of the Nix store.
      sandbox = true;
      # Automatically clean out old entries from nix store by detecting duplicates and creating hard links.
      # Only starts with new derivations, so run "nix-store --optimise" to clear out older cruft.
      # optimise.automatic = true below should handle this.
      auto-optimise-store = true;
      # Users with additional Nix daemon rights.
      # Can specify additional binary caches, import unsigned NARs (Nix Archives).
      trusted-users = [ "@wheel" "root" ];
      # Users allowed to connect to Nix daemon
      allowed-users = [ "@wheel" ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://arm.cachix.org/"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "arm.cachix.org-1:5BZ2kjoL1q6nWhlnrbAl+G7ThY7+HaBRD9PZzqZkbnM="
      ];
    };
    # Additional text appended to nix.conf
    extraOptions =
      let empty_registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}''; in
      ''
        # Enable flakes
        experimental-features = nix-command flakes recursive-nix
        flake-registry = ${empty_registry}

        builders-use-substitutes = true

        # Prevents garbage collector from deleting derivations.
        # Useful for querying and tracing options and dependencies for a store path.
        # https://ianthehenry.com/posts/how-to-learn-nix/saving-your-shell/
        keep-derivations = true

        # Prevents garbage collector from deleting outputs of derivations.
        keep-outputs = true
      '';

    registry.nixpkgs.flake = inputs.nixpkgs;

    # Garbage collection - deletes all unreachable paths in Nix store.
    gc = {
      # Run garbage collection automatically
      automatic = true;
      # Run once a week
      dates = "weekly";
      # Delete older than 7 days, stopping after "max-freed" bytes
      options = "--delete-older-than 7d --max-freed $((64 * 1024**3))";
    };
    # Optimiser settings
    # It seems that this is a scheduled job, as opposed to "autoOptimiseStore", which runs just in time.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # --------------------------------------------------------------------------------------
  # User config
  # --------------------------------------------------------------------------------------

  users.users.${hostParams.username} = {
    isNormalUser  = true;
    home  = "/home/${hostParams.username}";
    description  = "Mediaserver User";
    extraGroups  = [ "wheel" "networkmanager" "audio" "pulse" "pulse-access" ];
    # @TODO: Make this dynamic, not hard coded
    openssh.authorizedKeys.keys  = hostParams.sshKeys;
    hashedPassword = hostParams.hashedPassword;
  };

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  # --------------------------------------------------------------------------------------
  # Package config
  # --------------------------------------------------------------------------------------

  nixpkgs = {
    hostPlatform = system;
    config = {
      ## Allow proprietary packages.
      allowUnfree = true;
      ## Allow broken packages.
      # allowBroken = true;
      packageOverrides = pkgs: {
        unstable = import inputs.nixpkgs-unstable {
          config = config.nixpkgs.config;
          inherit system;
        };
        trunk = import inputs.nixpkgs-trunk {
          config = config.nixpkgs.config;
          inherit system;
        };
      };
    };
  };

  # --------------------------------------------------------------------------------------
  # Boot / Kernel
  # --------------------------------------------------------------------------------------

  # Disables writing to Nix store by mounting read-only. "false" should only be used as a last resort.
  # Nix mounts read-write automatically when it needs to write to it.
  boot.readOnlyNixStore = true;

  # --------------------------------------------------------------------------------------
  # Services
  # --------------------------------------------------------------------------------------

  # Does this conflict with librespot?
  services.resolved.enable = true;

  # Firmware/BIOS updates
  services.fwupd.enable = true;

  # Setting to true will kill things like tmux on logout
  services.logind.killUserProcesses = false;

  # network locator e.g. scanners and printers
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  services.gvfs.enable = true; # SMB mounts, trash, and other functionality
  services.tumbler.enable = true; # Thumbnail support for images

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # @TODO: Move to "environment"?
  services.printing.drivers = [ pkgs.brlaser ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable eternal terminal
  services.eternal-terminal.enable = true;

  # This will save you money and possibly your life!
  ## Not supported on raspberry pi?
  # services.thermald.enable = true;

  services.upower.enable = true;

  # Enable power management
  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  # --------------------------------------------------------------------------------------
  # i18n
  # --------------------------------------------------------------------------------------

  # @TODO: Make this UI configurable
  i18n.defaultLocale = "en_US.UTF-8";

  # --------------------------------------------------------------------------------------
  # Networking
  # --------------------------------------------------------------------------------------

  networking.search = [ "localdomain" ];

  networking.firewall.allowedTCPPorts = [
    2022    # eternal terminal
  ];

  # --------------------------------------------------------------------------------------
  # Base Packages
  # --------------------------------------------------------------------------------------

  programs.nix-ld.enable = true;

  programs.command-not-found.enable = true;
  programs.command-not-found.dbPath = "${inputs.nixpkgs}/programs.sqlite";

  programs.mosh.enable = true;

  # environment.variables.EDITOR = "neovim";
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  environment.interactiveShellInit = ''
    alias vi='nvim'
    alias vim='nvim'
  '';

  environment.systemPackages = with pkgs; [
    at-spi2-core
    backblaze-b2
    bashmount
    bfg-repo-cleaner
    bind
    ccze             # readable parsed system logs
    ## Not supported on raspberry pi
    # cpufrequtils
    distrobox
    dmidecode
    dos2unix
    eternal-terminal
    exfat
    exiftool
    ffmpeg
    file
    fio
    fx                # Terminal-based JSON viewer and processor
    gcc
    git
    git-lfs
    gnumake
    htop
    hwinfo
    iftop
    inetutils
    iotop
    iperf3
    luarocks
    lshw
    lsof
    lxqt.lxqt-policykit # For GVFS
    iw
    iwd
    jhead
    minicom
    neofetch
    neovim
    unstable.nil
    nix-index
    openssl
    # openjdk16-bootstrap
    p7zip
    pciutils
    powertop
    networkmanager
    sshpass
    steampipe
    tmux
    usbutils
    utillinux
    vulnix
    wireguard-tools
    wirelesstools
    wget
    xz
    zip
    zsh
  ];
}
