#!/usr/bin/env bash

set -e

if ! command -v nix &> /dev/null
then
    echo "nix could not be found. If it is installed, you may need to log out and log in again for it to be in your path."
    exit 1
fi

build_image() {
    HOST=$1
    FORMAT=$2
    EXT=$3
    nix build .#nixosConfigurations.${HOST}.config.system.build.$FORMAT
    mkdir -p ./build
    if [ -e ./${HOST} ]; then
        rm ./${HOST}
    fi
    mv ./result ./${HOST}
    rsync -L ./${HOST}/sd-image/*.zst ./build/${HOST}.$EXT
    chmod 750 ./build/${HOST}.$EXT
}

# clear up disk space
rm -rf ./build/*

## binfmt qemu compile
build_image mediaserver-rpi4 sdImage img.zst

## Cross Compile
## Much faster but sometimes fails. Run this first, then run qemu compile
# build_image mediaserver-rpi4-build sdImage img.zst

cd build
zstd -d mediaserver-rpi4.img.zst
rm mediaserver-rpi4.img.zst
# cd ..
# build_image mediaserver-x86 qcow qcow2
