#!/usr/bin/env bash

set -e

# Configuration
SCRIPT_NAME=$(basename "$0")
FLAKE_DIR="${FLAKE_DIR:-$(pwd)}"
BUILD_DIR=""
CONFIG_NAME="mediaserver-x86"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Run a NixOS x86 VM image locally for testing using QEMU/KVM.

Options:
  -f, --flake-dir DIR       Flake directory (default: current directory)
  -b, --build-dir DIR       Build directory containing images (default: ./build in flake dir)
  -c, --config NAME         Configuration name (default: mediaserver-x86)
  -m, --memory SIZE         VM memory size (default: 8G)
  -s, --smp COUNT          Number of CPUs (default: 4)
  -g, --gui                Enable GUI (default: auto-detect based on DISPLAY)
  -n, --no-gui             Disable GUI (force nographic mode)
  -h, --help               Show this help

Environment Variables:
  FLAKE_DIR               Default flake directory

Port Mappings:
  SSH:    localhost:2223 -> VM:22
  HTTPS:  localhost:8445 -> VM:443
  HTTP:   localhost:8885 -> VM:80

Examples:
  # Run VM from current directory
  $SCRIPT_NAME
  
  # Run VM from specific flake with custom memory
  $SCRIPT_NAME -f /path/to/my-flake -m 16G
  
  # Run VM in headless mode
  $SCRIPT_NAME --no-gui

SSH Access:
  Once the VM is running, you can SSH into it:
    ssh -p 2223 mediaserver@localhost

Note: This script requires QEMU/KVM to be installed on your system.
EOF
}

# Parse command line arguments
MEMORY="8G"
SMP="4"
GUI_MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--flake-dir)
            FLAKE_DIR="$2"
            shift 2
            ;;
        -b|--build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_NAME="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -s|--smp)
            SMP="$2"
            shift 2
            ;;
        -g|--gui)
            GUI_MODE="gui"
            shift
            ;;
        -n|--no-gui)
            GUI_MODE="nographic"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Detect OS for platform-specific paths
detect_os

# Set platform-specific paths
if [ "$OS" == "Fedora Linux" ]; then
    OVMF_NVRAM=/usr/share/OVMF/OVMF_VARS.fd
    OVMF_CODE=/usr/share/OVMF/OVMF_CODE.fd
    VIRTIOFSD=/usr/libexec/virtiofsd
    QEMU_BRIDGE_HELPER=/usr/libexec/qemu-bridge-helper
    QEMU_CMD="qemu-kvm"
elif [ "$OS" == "NixOS" ]; then
    OVMF_NVRAM=/var/lib/libvirt/qemu/nvram/nixos_VARS.fd
    OVMF_CODE=/var/run/libvirt/nix-ovmf/OVMF_CODE.fd
    VIRTIOFSD=$(which virtiofsd 2>/dev/null || echo "")
    QEMU_BRIDGE_HELPER=$(which qemu-bridge-helper 2>/dev/null || echo "")
    QEMU_CMD="qemu-system-x86_64"
elif [ "$OS" == "Ubuntu" ] || [ "$OS" == "Debian" ]; then
    OVMF_NVRAM=/usr/share/OVMF/OVMF_VARS.fd
    OVMF_CODE=/usr/share/OVMF/OVMF_CODE.fd
    VIRTIOFSD=/usr/libexec/virtiofsd
    QEMU_BRIDGE_HELPER=/usr/lib/qemu/qemu-bridge-helper
    QEMU_CMD="qemu-system-x86_64"
else
    log_warning "Unsupported OS: $OS"
    log_warning "Attempting to use default paths..."
    OVMF_NVRAM=/usr/share/OVMF/OVMF_VARS.fd
    OVMF_CODE=/usr/share/OVMF/OVMF_CODE.fd
    VIRTIOFSD=$(which virtiofsd 2>/dev/null || echo "")
    QEMU_BRIDGE_HELPER=$(which qemu-bridge-helper 2>/dev/null || echo "")
    QEMU_CMD="qemu-system-x86_64"
fi

# Check for required commands
if ! command -v "$QEMU_CMD" &> /dev/null && ! command -v qemu-system-x86_64 &> /dev/null; then
    log_error "QEMU not found. Please install QEMU/KVM."
    log_info "On Fedora: sudo dnf install qemu-kvm"
    log_info "On Ubuntu/Debian: sudo apt install qemu-kvm"
    exit 1
fi

# Use fallback if primary command not found
if ! command -v "$QEMU_CMD" &> /dev/null; then
    QEMU_CMD="qemu-system-x86_64"
fi

# Ensure flake directory is absolute path
FLAKE_DIR=$(realpath "$FLAKE_DIR")

# Set default build directory if not specified
if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$FLAKE_DIR/build"
fi
BUILD_DIR=$(realpath "$BUILD_DIR" 2>/dev/null || echo "$BUILD_DIR")

# Check for image file
IMAGE_FILE="$BUILD_DIR/${CONFIG_NAME}.qcow2"
if [[ ! -f "$IMAGE_FILE" ]]; then
    log_error "VM image not found: $IMAGE_FILE"
    log_info "Please build the image first using build-image.sh"
    log_info "Example: ./build-image.sh -c $CONFIG_NAME"
    exit 1
fi

# Determine GUI mode
if [[ -z "$GUI_MODE" ]]; then
    if [ x$DISPLAY != x ]; then
        GUI_FLAG=""
        log_info "GUI mode enabled (DISPLAY detected)"
    else
        GUI_FLAG="-nographic"
        log_info "Headless mode enabled (no DISPLAY)"
    fi
elif [[ "$GUI_MODE" == "nographic" ]]; then
    GUI_FLAG="-nographic"
    log_info "Headless mode enabled (forced)"
else
    GUI_FLAG=""
    log_info "GUI mode enabled (forced)"
fi

# Check for OVMF files (for UEFI boot)
USE_UEFI=false
if [[ -f "$OVMF_CODE" ]]; then
    USE_UEFI=true
    # Create a copy of NVRAM for this VM
    NVRAM_FILE="$BUILD_DIR/${CONFIG_NAME}_VARS.fd"
    if [[ ! -f "$NVRAM_FILE" ]] && [[ -f "$OVMF_NVRAM" ]]; then
        cp "$OVMF_NVRAM" "$NVRAM_FILE"
        chmod 644 "$NVRAM_FILE"
    fi
else
    log_warning "OVMF not found. VM will use legacy BIOS boot."
fi

# Set up virtiofs if available (for sharing flake directory with VM)
VIRTIOFS_PIDS=()
VIRTIOFS_ARGS=""
if [[ -n "$VIRTIOFSD" ]] && [[ -x "$VIRTIOFSD" ]]; then
    log_info "Setting up virtiofs for directory sharing..."
    SOCKET_PATH="/tmp/vhostqemu-$$"
    
    # Start virtiofsd
    sudo "$VIRTIOFSD" --socket-path "$SOCKET_PATH" --shared-dir "$FLAKE_DIR" --cache auto &
    VIRTIOFS_PIDS+=($!)
    
    # Add virtiofs device arguments
    VIRTIOFS_ARGS="-chardev socket,id=char0,path=$SOCKET_PATH"
    VIRTIOFS_ARGS="$VIRTIOFS_ARGS -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=flake_share"
    VIRTIOFS_ARGS="$VIRTIOFS_ARGS -object memory-backend-file,id=mem,size=$MEMORY,mem-path=/dev/shm,share=on"
    VIRTIOFS_ARGS="$VIRTIOFS_ARGS -numa node,memdev=mem"
    
    log_info "Flake directory will be available in VM at /mnt/flake"
else
    log_warning "virtiofsd not available. Directory sharing disabled."
fi

# Build QEMU command
QEMU_ARGS="$GUI_FLAG"
QEMU_ARGS="$QEMU_ARGS -cpu host"
QEMU_ARGS="$QEMU_ARGS -enable-kvm"
QEMU_ARGS="$QEMU_ARGS -smp $SMP"

# Add memory (if not using virtiofs with shared memory)
if [[ -z "$VIRTIOFS_ARGS" ]]; then
    QEMU_ARGS="$QEMU_ARGS -m $MEMORY"
fi

# Add UEFI or BIOS
if [[ "$USE_UEFI" == "true" ]]; then
    QEMU_ARGS="$QEMU_ARGS -drive file=$OVMF_CODE,if=pflash,format=raw,unit=0,readonly=on"
    QEMU_ARGS="$QEMU_ARGS -drive file=$NVRAM_FILE,if=pflash,format=raw,unit=1"
fi

# Add disk
QEMU_ARGS="$QEMU_ARGS -hda $IMAGE_FILE"

# Add network with port forwarding
QEMU_ARGS="$QEMU_ARGS -net nic"
QEMU_ARGS="$QEMU_ARGS -net user,hostfwd=tcp::2223-:22,hostfwd=tcp::8445-:443,hostfwd=tcp::8885-:80"

# Add virtiofs arguments if available
if [[ -n "$VIRTIOFS_ARGS" ]]; then
    QEMU_ARGS="$VIRTIOFS_ARGS $QEMU_ARGS"
fi

log_info "Starting VM: $CONFIG_NAME"
log_info "Image: $IMAGE_FILE"
log_info "Memory: $MEMORY, CPUs: $SMP"
log_info "Port mappings:"
log_info "  SSH:   localhost:2223 -> VM:22"
log_info "  HTTPS: localhost:8445 -> VM:443"
log_info "  HTTP:  localhost:8885 -> VM:80"

# Cleanup function
cleanup() {
    log_info "Shutting down VM..."
    
    # Kill virtiofsd if running
    for pid in ${VIRTIOFS_PIDS[@]}; do
        if kill -0 $pid 2>/dev/null; then
            sudo kill $pid 2>/dev/null || true
        fi
    done
    
    # Clean up socket
    if [[ -n "$SOCKET_PATH" ]] && [[ -e "$SOCKET_PATH" ]]; then
        sudo rm -f "$SOCKET_PATH"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Run QEMU
log_info "Launching QEMU..."
if [[ -n "$VIRTIOFS_ARGS" ]]; then
    # Need sudo for virtiofs
    sudo -E $QEMU_CMD $QEMU_ARGS
else
    $QEMU_CMD $QEMU_ARGS
fi

log_info "VM shutdown complete"