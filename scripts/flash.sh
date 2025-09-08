#!/usr/bin/env bash

set -e

# Configuration
SCRIPT_NAME=$(basename "$0")
FLAKE_DIR="${FLAKE_DIR:-$(pwd)}"
BUILD_DIR=""

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

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <device>

Flash a NixOS Raspberry Pi image to an SD card or USB device.

Arguments:
  device          Target device (e.g., /dev/sda, /dev/mmcblk0)

Options:
  -f, --flake-dir DIR       Flake directory (default: current directory)
  -b, --build-dir DIR       Build directory containing images (default: ./build in flake dir)
  -i, --image FILE          Specific image file to flash (overrides auto-detection)
  -c, --config NAME         Configuration name to flash (e.g., mediaserver, partymusic)
  -y, --yes                 Skip confirmation prompt
  -h, --help               Show this help

Environment Variables:
  FLAKE_DIR               Default flake directory

Examples:
  # Flash the first available image to /dev/sda
  $SCRIPT_NAME /dev/sda
  
  # Flash specific configuration
  $SCRIPT_NAME -c partymusic /dev/mmcblk0
  
  # Flash specific image file
  $SCRIPT_NAME -i ./custom-image.img /dev/sdb
  
  # Flash from different flake directory
  $SCRIPT_NAME -f /path/to/my-flake /dev/sda

Safety:
  This script will prompt for confirmation before writing to the device.
  Use -y to skip the confirmation (use with caution!).
EOF
}

# Function to check if device exists and is valid
check_device() {
    local device=$1
    
    if [[ ! -b "$device" ]]; then
        log_error "Device $device does not exist or is not a block device"
        return 1
    fi
    
    # Check if device is mounted
    if mount | grep -q "^$device"; then
        log_error "Device $device appears to be mounted. Please unmount it first."
        return 1
    fi
    
    return 0
}

# Function to confirm the operation
confirm_operation() {
    local device=$1
    local image=$2
    
    log_warning "WARNING: This will COMPLETELY ERASE all data on $device"
    echo
    echo "Image to write: $image"
    echo "Target device:  $device"
    
    # Try to get device info
    if command -v lsblk &> /dev/null; then
        echo
        echo "Device information:"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT "$device" 2>/dev/null || true
    fi
    
    echo
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_info "Operation cancelled by user"
        return 1
    fi
    
    return 0
}

# Parse command line arguments
IMAGE_FILE=""
CONFIG_NAME=""
SKIP_CONFIRM=false

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
        -i|--image)
            IMAGE_FILE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_NAME="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
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

# Check required arguments
if [[ $# -lt 1 ]]; then
    log_error "Missing required argument: device"
    usage
    exit 1
fi

DEVICE="$1"

# Check for required commands
if ! command -v dd &> /dev/null; then
    log_error "dd command not found. Please install coreutils."
    exit 1
fi

# Check if pv is available for progress indication
HAS_PV=false
if command -v pv &> /dev/null; then
    HAS_PV=true
else
    log_warning "pv command not found. Install it for progress indication during flashing."
fi

# Ensure flake directory is absolute path
FLAKE_DIR=$(realpath "$FLAKE_DIR")

# Set default build directory if not specified
if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$FLAKE_DIR/build"
fi
BUILD_DIR=$(realpath "$BUILD_DIR" 2>/dev/null || echo "$BUILD_DIR")

# Check device
if ! check_device "$DEVICE"; then
    exit 1
fi

# Determine which image to flash
if [[ -n "$IMAGE_FILE" ]]; then
    # Specific image file provided
    if [[ ! -f "$IMAGE_FILE" ]]; then
        log_error "Image file does not exist: $IMAGE_FILE"
        exit 1
    fi
    IMAGE_TO_FLASH="$IMAGE_FILE"
elif [[ -n "$CONFIG_NAME" ]]; then
    # Look for specific configuration image
    IMAGE_TO_FLASH="$BUILD_DIR/${CONFIG_NAME}.img"
    if [[ ! -f "$IMAGE_TO_FLASH" ]]; then
        # Try with -rpi4 suffix
        IMAGE_TO_FLASH="$BUILD_DIR/${CONFIG_NAME}-rpi4.img"
        if [[ ! -f "$IMAGE_TO_FLASH" ]]; then
            log_error "No image found for configuration: $CONFIG_NAME"
            log_error "Looked in: $BUILD_DIR"
            log_error "Available images:"
            ls -la "$BUILD_DIR"/*.img 2>/dev/null || echo "  No .img files found"
            exit 1
        fi
    fi
else
    # Auto-detect image from build directory
    if [[ ! -d "$BUILD_DIR" ]]; then
        log_error "Build directory does not exist: $BUILD_DIR"
        log_error "Please build an image first using build-image.sh"
        exit 1
    fi
    
    # Find .img files in build directory
    mapfile -t IMAGES < <(find "$BUILD_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null)
    
    if [[ ${#IMAGES[@]} -eq 0 ]]; then
        log_error "No .img files found in $BUILD_DIR"
        log_error "Please build an image first using build-image.sh"
        exit 1
    elif [[ ${#IMAGES[@]} -eq 1 ]]; then
        IMAGE_TO_FLASH="${IMAGES[0]}"
        log_info "Auto-detected image: $(basename "$IMAGE_TO_FLASH")"
    else
        log_error "Multiple images found. Please specify which one to flash:"
        for img in "${IMAGES[@]}"; do
            echo "  - $(basename "$img")"
        done
        echo
        echo "Use -c CONFIG_NAME or -i IMAGE_FILE to specify"
        exit 1
    fi
fi

# Get image size for progress indication
IMAGE_SIZE=$(stat --printf="%s" "$IMAGE_TO_FLASH" 2>/dev/null || stat -f%z "$IMAGE_TO_FLASH" 2>/dev/null || echo "0")
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))

log_info "Image file: $IMAGE_TO_FLASH"
log_info "Image size: ${IMAGE_SIZE_MB}MB"
log_info "Target device: $DEVICE"

# Confirm operation unless skipped
if [[ "$SKIP_CONFIRM" != "true" ]]; then
    if ! confirm_operation "$DEVICE" "$IMAGE_TO_FLASH"; then
        exit 1
    fi
fi

# Perform the flash operation
log_info "Starting flash operation..."
log_warning "Do not remove the device or interrupt this process!"

# Check if we need sudo
SUDO=""
if [[ ! -w "$DEVICE" ]]; then
    SUDO="sudo"
    log_info "Root privileges required to write to $DEVICE"
fi

# Flash the image
if [[ "$HAS_PV" == "true" ]]; then
    # With progress indication
    if dd if="$IMAGE_TO_FLASH" | pv -s "$IMAGE_SIZE" | $SUDO dd of="$DEVICE" bs=4M conv=fsync status=none; then
        log_success "Image successfully flashed to $DEVICE"
    else
        log_error "Failed to flash image to $DEVICE"
        exit 1
    fi
else
    # Without progress indication
    log_info "This may take several minutes..."
    if $SUDO dd if="$IMAGE_TO_FLASH" of="$DEVICE" bs=4M conv=fsync status=progress; then
        log_success "Image successfully flashed to $DEVICE"
    else
        log_error "Failed to flash image to $DEVICE"
        exit 1
    fi
fi

# Sync to ensure all data is written
log_info "Syncing data to device..."
sync

log_success "Flash operation completed successfully!"
log_info "You can now safely remove the device and use it to boot your Raspberry Pi"