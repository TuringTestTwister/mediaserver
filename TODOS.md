TODOS
=====

* Use this example of loading one flake from another to keep secrets and other sensitive data separate
  * https://github.com/tstat/raspberry-pi-nix-example/blob/master/flake.nix
* Get Bluetooth working
  * https://nixos.wiki/wiki/Bluetooth
  * Get wireless firmware
    * https://github.com/tstat/raspberry-pi-nix/blob/master/overlays/default.nix
    * https://github.com/tstat/raspberry-pi-nix/blob/master/overlays/raspberrypi-wireless-firmware.nix
  * Gets it to work at all:
    * https://github.com/NixOS/nixpkgs/issues/123725#issuecomment-1613705556
    * BUT, it stutters
* Make flake for host machine
  * virtual machine config
  * common binary cache config for arm
* Raspbery pi cross compilation tips
  * https://www.reddit.com/r/NixOS/comments/zezq4m/building_arm_packages_on_a_x86_machine_is/
* Add eternal terminal
  * https://eternalterminal.dev/
* Add snapcast
  * For multi-room sync, not for playback
  * Server would stream to Mopidy
  * https://github.com/badaix/snapcast
* Music Servers
  * https://github.com/volumio/volumio3-backend
    * Audiophile music server, multiple backends
  * https://moodeaudio.org/
    * Audiophile music server, multiple backends
  * Jellyfin
  * Mopidy
    * Installed, but nothing works so far
  * https://docs.koel.dev
    * Local, Last.fm, Spotify, Youtube, iTunes
  * https://beets.io/
    * Local, automatically cataloged
  * https://www.navidrome.org
    * Local, spotify-clone, low resource, multi-user, sharing
  * https://ampache.org/
    * Local, Soundcloud?, lyrics, video
  * https://musikcube.com/
    * Local, terminal based
  * https://www.azuracast.com/
    * Local, web radio, live DJing, radio stations
  * https://airsonic.github.io/
    * Local, srteaming

