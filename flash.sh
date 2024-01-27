#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    >&2 echo "No arguments provided. pass a device, e.g. /dev/sda"
    exit 1
fi

DEVICE=$1

SIZE=$(stat --printf="%s" build/mediaserver-rpi4.img)
dd if=build/mediaserver-rpi4.img | pv -s $SIZE | sudo dd of=$1 bs=4M conv=fsync
