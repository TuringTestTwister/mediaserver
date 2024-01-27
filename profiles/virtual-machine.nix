{ pkgs, hostParams, ... }:
{
  environment.systemPackages = with pkgs; [
    libvirt
    virtiofsd
  ];

  systemd.mounts = [
    {
      what = "mount_mediaserver_source";
      where = "/home/${hostParams.username}/nixcfg";
      type = "virtiofs";
      wantedBy = [ "multi-user.target" ];
      enable = true;
    }
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      # Use maximum resolution in systemd-boot for hidpi
      consoleMode = "max";
    };
    efi = {
      canTouchEfiVariables = true;
    };
  };

  boot.extraModprobeConfig = "options kvm_intel nested=1";
  boot.kernelParams = [
    "intel_iommu=on"
    "cgroup_enable=freezer"
  ];
}
