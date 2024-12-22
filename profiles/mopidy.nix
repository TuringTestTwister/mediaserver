{ lib, pkgs, hostParams, ... }:
{
  services.mopidy = {
    enable = true;
    extensionPackages = with pkgs; [
      mopidy-bandcamp
      mopidy-iris
      ## temp disabled
      # mopidy-jellyfin
      mopidy-local
      mopidy-moped
      ## Failure loading python module "mem"
      # mopidy-mopify
      mopidy-mpd
      mopidy-mpris
      mopidy-muse
      ## Can't get mopidy app to start stream, or mopidy backend isn't receiving request
      mopidy-podcast
      mopidy-somafm
      ## Broken - soundcloud doesn't allow for API signups anymore, and mopidy's API key hit quota
      mopidy-soundcloud
      ## Broken - yt-dl needs to be updated
      mopidy-youtube
      ## nix store conflict
      # mopidy-ytmusic
    ];
    configuration = ''
      [mpd]

      hostname = ::

      [audio]

      # output = pulsesink server=127.0.0.1
      mixer = software
      mixer_volume =
      output = autoaudiosink
      buffer_time =

      [http]

      enabled = true
      hostname = ::
      port = 6680
      zeroconf = $hostname
      # zeroconf = $hostname:$port
      # crsf_protection = true

      [stream]

      enabled = true
      protocols =
          http
          https
          mms
          rtmp
          rtmps
          rtsp
      timeout = 5000
      metadata_blacklist =

      [soundcloud]

      auth_token = changeme

      [jellyfin]

      hostname = jellyfin.lan
      username = changeme
      password = changeme
      # user_id = userid (Optional: Needed for token authentication)
      # token = token (Optional: Use for authentication instead of username and password)
      # libraries = Library1, Library2 (Optional: will default to "Music" if left undefined)
      # albumartistsort = False (Optional: will default to True if left undefined)
      # album_format = {ProductionYear} - {Name} (Optional: will default to "{Name}" if left undefined)
      # max_bitrate = number
    '';
  };

  networking.firewall.allowedTCPPorts = [ 6660 6680 ];
}

