#!/usr/bin/env bash

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

if [ "$OS" == "Fedora Linux" ]; then
    OVMF_NVRAM=/usr/share/OVMF/OVMF_VARS.fd
    OVMF_CODE=/usr/share/OVMF/OVMF_CODE.fd
    VIRTIOFSD=/usr/libexec/virtiofsd
    QEMU_BRIDGE_HELPER=/usr/libexec/qemu-bridge-helper
elif [ "$OS" == "NixOS" ]; then
    OVMF_NVRAM=/var/lib/libvirt/qemu/nvram/nixos_VARS.fd
    OVMF_CODE=/var/run/libvirt/nix-ovmf/OVMF_CODE.fd
    VIRTIOFSD=$(which virtiofsd)
    QEMU_BRIDGE_HELPER=$(which qemu-bridge-helper)
else
    echo "Unsupported OS";
    exit 1
fi

if [ x$DISPLAY != x ] ; then
    GUI_FLAG=
else
    GUI_FLAG=-nographic
fi

# @TODO: need to move to netdev bridge type?
# SEE: https://futurewei-cloud.github.io/ARM-Datacenter/qemu/network-aarch64-qemu-guests/
sudo cp $OVMF_NVRAM ./build/OVMF_VARS.fd
sudo chown $USER:users ./build/OVMF_VARS.fd
# @TODO: What if virtiofsd is already running elsewhere? Can it be run as a service?
sudo $VIRTIOFSD --socket-path /tmp/vhostqemu --shared-dir ./ --cache auto &
pids[1]=$!
sudo -E qemu-kvm \
    $GUI_FLAG \
    -cpu host \
    -enable-kvm \
    -chardev socket,id=char0,path=/tmp/vhostqemu \
    -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=mount_mediaserver_source \
    -object memory-backend-file,id=mem,size=8G,mem-path=/dev/shm,share=on \
    -numa node,memdev=mem \
    -drive file=$OVMF_CODE,if=pflash,format=raw,unit=0,readonly=on \
    -drive file=./build/OVMF_VARS.fd,if=pflash,format=raw,unit=1 \
    -hda ./build/mediaserver-x86.qcow2 \
    -smp 4 \
    -m 8G \
    -net nic \
    -net user,hostfwd=tcp::2223-:22,hostfwd=tcp::8445-:443,hostfwd=tcp::8885-:80 \
    &
pids[2]=$!

for pid in ${pids[*]}; do
    wait $pid
done
