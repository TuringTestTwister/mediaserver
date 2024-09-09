TODOS
=====

* Move to wpa_supplicant
  * Use freq_list=5170 5180 5190 5200 5210 5220 5230 5240 5260 5280 5300 5320 5500 5520 5540 5560 5580 5600 5620 5640 5660 5680 5700 5720 5745 5765 5785 5805 5825
  * https://en.wikipedia.org/wiki/List_of_WLAN_channels#5_GHz_(802.11a/h/n/ac/ax/be)
* Move to nixos-anywhere deployment
  * Make flake for host machine
    * virtual machine config
    * common binary cache config for arm
* Get rid of rubber-duck-5g
* Figure out bluetooth streaming to snapcast-sink
* Use this example of loading one flake from another to keep secrets and other sensitive data separate
  * https://github.com/tstat/raspberry-pi-nix-example/blob/master/flake.nix
* Raspbery pi cross compilation tips
  * https://www.reddit.com/r/NixOS/comments/zezq4m/building_arm_packages_on_a_x86_machine_is/
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

DONE
----
* Get Bluetooth working
  * https://nixos.wiki/wiki/Bluetooth
  * Get wireless firmware
    * https://github.com/tstat/raspberry-pi-nix/blob/master/overlays/default.nix
    * https://github.com/tstat/raspberry-pi-nix/blob/master/overlays/raspberrypi-wireless-firmware.nix
  * Gets it to work at all:
    * https://github.com/NixOS/nixpkgs/issues/123725#issuecomment-1613705556
    * BUT, it stutters
* Add eternal terminal
  * https://eternalterminal.dev/
