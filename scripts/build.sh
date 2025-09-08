#!/usr/bin/env bash

set -e

# Configuration
SCRIPT_NAME=$(basename "$0")
FLAKE_DIR="${FLAKE_DIR:-$(pwd)}"
CONFIG_NAME=""

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

Rebuild NixOS system configuration locally (for use within a NixOS system).

Arguments:
  CONFIG_NAME    NixOS configuration name from flake (default: current hostname)

Options:
  -f, --flake-dir DIR       Flake directory (default: current directory)
  -s, --switch              Switch to new configuration (default)
  -b, --boot                Set as boot configuration without switching
  -t, --test                Test configuration without making permanent
  -n, --dry-run             Show what would be built without building
  -j, --max-jobs NUM        Maximum number of build jobs (default: auto)
  -h, --help               Show this help

Environment Variables:
  FLAKE_DIR               Default flake directory

Examples:
  # Rebuild current system from current directory
  $SCRIPT_NAME
  
  # Rebuild specific configuration from specific flake
  $SCRIPT_NAME -f /path/to/my-flake mediaserver
  
  # Test configuration without making permanent
  $SCRIPT_NAME --test

Note: This script must be run on a NixOS system and typically requires sudo privileges.
EOF
}

# Parse command line arguments
ACTION="switch"
MAX_JOBS=""
DRY_RUN=false

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
        -s|--switch)
            ACTION="switch"
            shift
            ;;
        -b|--boot)
            ACTION="boot"
            shift
            ;;
        -t|--test)
            ACTION="test"
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -j|--max-jobs)
            MAX_JOBS="$2"
            shift 2
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

# Check if running on NixOS
if [[ ! -f /etc/NIXOS ]]; then
    log_warning "This doesn't appear to be a NixOS system."
    log_warning "This script is intended for rebuilding NixOS systems locally."
    log_warning "For remote deployment, use remote-deploy.sh instead."
    read -p "Continue anyway? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Ensure flake directory is absolute path
FLAKE_DIR=$(realpath "$FLAKE_DIR")

# Validate flake directory
if [[ ! -f "$FLAKE_DIR/flake.nix" ]]; then
    log_error "No flake.nix found in $FLAKE_DIR"
    exit 1
fi

# Determine configuration name
if [[ -z "$CONFIG_NAME" ]]; then
    # Try to use current hostname
    CONFIG_NAME=$(hostname)
    log_info "No configuration specified, using current hostname: $CONFIG_NAME"
fi

# Build the flake reference
FLAKE_REF="$FLAKE_DIR#$CONFIG_NAME"

log_info "Building NixOS configuration: $CONFIG_NAME"
log_info "Flake directory: $FLAKE_DIR"
log_info "Action: $ACTION"

# Build the command
CMD="nixos-rebuild"

# Add action
CMD="$CMD $ACTION"

# Add flake reference
CMD="$CMD --flake '$FLAKE_REF'"

# Add max-jobs if specified
if [[ -n "$MAX_JOBS" ]]; then
    CMD="$CMD --max-jobs $MAX_JOBS"
fi

# Add verbose logging
CMD="$CMD -L"

# Check if we need sudo
if [[ $EUID -ne 0 ]]; then
    log_info "This operation requires root privileges."
    CMD="sudo $CMD"
fi

# Execute the rebuild
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run mode - would execute:"
    echo "  $CMD"
else
    log_info "Executing rebuild..."
    if eval "$CMD"; then
        log_success "System rebuild completed successfully!"
        
        case "$ACTION" in
            switch)
                log_info "New configuration has been activated."
                ;;
            boot)
                log_info "New configuration will be activated on next boot."
                ;;
            test)
                log_info "New configuration is active for testing (not made permanent)."
                log_warning "Changes will be lost on reboot unless you run with --switch"
                ;;
        esac
    else
        log_error "System rebuild failed!"
        exit 1
    fi
fi