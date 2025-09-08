#!/usr/bin/env bash

set -e

# Configuration
SCRIPT_NAME=$(basename "$0")
FLAKE_DIR="${FLAKE_DIR:-$(pwd)}"

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
Usage: $SCRIPT_NAME [OPTIONS] [CONFIG_NAME]

Build a NixOS system image for Raspberry Pi or x86 systems.

Arguments:
  CONFIG_NAME    NixOS configuration name from flake (default: all configured systems)

Options:
  -f, --flake-dir DIR       Flake directory (default: current directory)
  -o, --output-dir DIR      Output directory for built images (default: ./build in flake dir)
  -k, --keep-compressed     Keep compressed images (don't decompress .zst files)
  -h, --help               Show this help

Environment Variables:
  FLAKE_DIR               Default flake directory

Examples:
  # Build all configured images
  $SCRIPT_NAME
  
  # Build specific configuration from specific flake
  $SCRIPT_NAME -f /path/to/my-flake mediaserver
  
  # Build and keep compressed
  $SCRIPT_NAME --keep-compressed partymusic

Note: This script will detect the appropriate image format based on the system architecture.
EOF
}

build_image() {
    local HOST=$1
    local FORMAT=$2
    local EXT=$3
    local FLAKE_REF="$FLAKE_DIR#nixosConfigurations.${HOST}"
    
    log_info "Building image for $HOST (format: $FORMAT)..."
    
    if ! nix build "$FLAKE_REF.config.system.build.$FORMAT"; then
        log_error "Failed to build image for $HOST"
        return 1
    fi
    
    log_info "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    # Handle the result symlink
    if [ -L ./result ]; then
        local TEMP_RESULT="${HOST}-result"
        if [ -e "./${TEMP_RESULT}" ]; then
            rm -rf "./${TEMP_RESULT}"
        fi
        mv ./result "./${TEMP_RESULT}"
        
        # Copy the image to build directory
        if [ "$FORMAT" = "sdImage" ]; then
            # For SD images, look in sd-image subdirectory
            if ls "./${TEMP_RESULT}/sd-image"/*.zst 1> /dev/null 2>&1; then
                rsync -L "./${TEMP_RESULT}/sd-image"/*.zst "$OUTPUT_DIR/${HOST}.$EXT"
                chmod 644 "$OUTPUT_DIR/${HOST}.$EXT"
                log_success "Image built: $OUTPUT_DIR/${HOST}.$EXT"
            else
                log_error "No image found in ${TEMP_RESULT}/sd-image/"
                return 1
            fi
        else
            # For other formats, look in the root
            if ls "./${TEMP_RESULT}"/*."${EXT%.*}" 1> /dev/null 2>&1; then
                rsync -L "./${TEMP_RESULT}"/*."${EXT%.*}" "$OUTPUT_DIR/${HOST}.$EXT"
                chmod 644 "$OUTPUT_DIR/${HOST}.$EXT"
                log_success "Image built: $OUTPUT_DIR/${HOST}.$EXT"
            else
                log_error "No image found in ${TEMP_RESULT}/"
                return 1
            fi
        fi
        
        # Cleanup temporary result
        rm -rf "./${TEMP_RESULT}"
    else
        log_error "Build did not produce a result symlink"
        return 1
    fi
}

# Parse command line arguments
KEEP_COMPRESSED=false
OUTPUT_DIR=""
CONFIG_NAME=""

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
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -k|--keep-compressed)
            KEEP_COMPRESSED=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            CONFIG_NAME="$1"
            shift
            ;;
    esac
done

# Check for nix command
if ! command -v nix &> /dev/null; then
    log_error "nix could not be found. If it is installed, you may need to log out and log in again for it to be in your path."
    exit 1
fi

# Ensure flake directory is absolute path
FLAKE_DIR=$(realpath "$FLAKE_DIR")

# Validate flake directory
if [[ ! -f "$FLAKE_DIR/flake.nix" ]]; then
    log_error "No flake.nix found in $FLAKE_DIR"
    exit 1
fi

# Set default output directory if not specified
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$FLAKE_DIR/build"
fi
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

log_info "Using flake directory: $FLAKE_DIR"
log_info "Output directory: $OUTPUT_DIR"

# Clear up disk space in output directory
if [ -d "$OUTPUT_DIR" ]; then
    log_warning "Cleaning existing build directory..."
    rm -rf "$OUTPUT_DIR"/*
fi

# If no specific config name provided, try to detect available configurations
if [[ -z "$CONFIG_NAME" ]]; then
    log_info "No specific configuration specified, attempting to build all Raspberry Pi configurations..."
    
    # Try common Raspberry Pi configuration names
    CONFIGS_TO_BUILD=()
    for config in mediaserver partymusic speakerserver mediaserver-rpi4 mediaserver-rpi4-cross-compile; do
        # Check if this configuration exists in the flake
        if nix eval --json "$FLAKE_DIR#nixosConfigurations.$config" &>/dev/null; then
            CONFIGS_TO_BUILD+=("$config")
        fi
    done
    
    if [ ${#CONFIGS_TO_BUILD[@]} -eq 0 ]; then
        log_error "No configurations found in flake. Please specify a configuration name."
        exit 1
    fi
    
    log_info "Found configurations: ${CONFIGS_TO_BUILD[*]}"
else
    CONFIGS_TO_BUILD=("$CONFIG_NAME")
fi

# Build each configuration
for config in "${CONFIGS_TO_BUILD[@]}"; do
    log_info "Processing configuration: $config"
    
    # Determine the system architecture and format
    SYSTEM_ARCH=$(nix eval --raw "$FLAKE_DIR#nixosConfigurations.$config.config.nixpkgs.system" 2>/dev/null || echo "unknown")
    
    if [[ "$SYSTEM_ARCH" == "aarch64-linux" ]]; then
        # Raspberry Pi image
        build_image "$config" "sdImage" "img.zst"
        
        # Decompress if requested
        if [[ "$KEEP_COMPRESSED" == "false" && -f "$OUTPUT_DIR/$config.img.zst" ]]; then
            log_info "Decompressing $config.img.zst..."
            (cd "$OUTPUT_DIR" && zstd -d "$config.img.zst" && rm "$config.img.zst")
            log_success "Image decompressed: $OUTPUT_DIR/$config.img"
        fi
    elif [[ "$SYSTEM_ARCH" == "x86_64-linux" ]]; then
        # x86 qcow2 image
        build_image "$config" "qcow" "qcow2"
    else
        log_warning "Unknown or unsupported system architecture for $config: $SYSTEM_ARCH"
    fi
done

log_success "All image builds completed!"
log_info "Images are available in: $OUTPUT_DIR"

# List built images
if [ -d "$OUTPUT_DIR" ]; then
    log_info "Built images:"
    ls -lh "$OUTPUT_DIR"
fi