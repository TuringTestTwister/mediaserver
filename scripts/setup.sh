#!/usr/bin/env bash

set -e

# Configuration
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(dirname "$(realpath "$0")")

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

Set up development environment for building and deploying NixOS mediaserver images.

Options:
  -n, --nix-only           Only install Nix, skip other dependencies
  -d, --deps-only          Only install dependencies, skip Nix
  -c, --check              Check installation status without installing
  -h, --help              Show this help

Supported Operating Systems:
  - Fedora Linux
  - Ubuntu/Debian (partial support)
  - NixOS (check only)

This script will install:
  - Nix package manager (if not already installed)
  - Required system packages (qemu, kvm, etc.)
  - Set up necessary user groups

Examples:
  # Full setup
  $SCRIPT_NAME
  
  # Check current setup status
  $SCRIPT_NAME --check
  
  # Install only Nix
  $SCRIPT_NAME --nix-only

Note: You may need to log out and log back in after setup for group changes to take effect.
EOF
}

check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        log_success "$name is installed ($(which $cmd))"
        return 0
    else
        log_warning "$name is not installed"
        return 1
    fi
}

check_group_membership() {
    local group=$1
    
    if id -nG "$USER" | grep -qw "$group"; then
        log_success "User $USER is in group $group"
        return 0
    else
        log_warning "User $USER is not in group $group"
        return 1
    fi
}

check_disk_space() {
    # Get free space on root partition in GB
    FREE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    
    if [ "$FREE" -lt 10 ]; then
        log_warning "Low disk space: ${FREE}GB free (minimum recommended: 10GB)"
        return 1
    else
        log_success "Disk space: ${FREE}GB free"
        return 0
    fi
}

check_installation() {
    log_info "Checking installation status..."
    echo
    
    local all_good=true
    
    # Check Nix
    if ! check_command "nix" "Nix"; then
        all_good=false
    fi
    
    # Check QEMU/KVM
    if ! check_command "qemu-img" "QEMU tools"; then
        all_good=false
    fi
    
    if ! check_command "qemu-system-x86_64" "QEMU x86_64" && ! check_command "qemu-kvm" "QEMU KVM"; then
        all_good=false
    fi
    
    # Check optional tools
    check_command "virtiofsd" "virtiofsd (optional)"
    check_command "pv" "pv (optional - for progress bars)"
    
    # Check groups
    if [ "$(getent group nixbld)" ]; then
        check_group_membership "nixbld"
    fi
    
    if [ "$(getent group kvm)" ]; then
        check_group_membership "kvm"
    fi
    
    if [ "$(getent group libvirt)" ]; then
        check_group_membership "libvirt"
    fi
    
    # Check disk space
    check_disk_space
    
    echo
    if [ "$all_good" = true ]; then
        log_success "All required components are installed!"
    else
        log_warning "Some components are missing. Run without --check to install them."
    fi
}

install_nix_fedora() {
    if command -v nix &> /dev/null; then
        log_success "Nix is already installed"
        return 0
    fi
    
    if [ -e /nix/var/nix/profiles/system/bin/nix ]; then
        log_warning "Nix is installed but not in your PATH"
        log_info "Please log out and log back in to update your PATH"
        return 0
    fi
    
    log_info "Installing Nix..."
    
    # Use nix-installer for better compatibility
    log_info "Downloading and installing Nix from nix-installer..."
    RPM_URL=https://nix-community.github.io/nix-installers/x86_64/nix-multi-user-2.17.1.rpm
    
    if ! sudo rpm -i "$RPM_URL"; then
        log_error "Failed to install Nix"
        log_info "Trying alternative installation method..."
        
        # Alternative: Official installer
        if ! sh <(curl -L https://nixos.org/nix/install) --daemon; then
            log_error "Failed to install Nix via official installer"
            log_info "You may need to disable SELinux temporarily:"
            log_info "  sudo setenforce 0"
            log_info "  # Run the installer"
            log_info "  sudo setenforce 1"
            return 1
        fi
    fi
    
    log_success "Nix installed successfully"
    log_info "Please log out and log back in to use Nix"
}

install_nix_debian() {
    if command -v nix &> /dev/null; then
        log_success "Nix is already installed"
        return 0
    fi
    
    log_info "Installing Nix..."
    
    # Official installer usually works well on Debian/Ubuntu
    if ! sh <(curl -L https://nixos.org/nix/install) --daemon; then
        log_error "Failed to install Nix"
        return 1
    fi
    
    log_success "Nix installed successfully"
    log_info "Please log out and log back in to use Nix"
}

setup_groups() {
    local needs_relogin=false
    
    # Create nixbld group if needed
    if [ ! "$(getent group nixbld)" ]; then
        log_info "Creating nixbld group..."
        sudo groupadd nixbld
    fi
    
    # Add user to nixbld group
    if ! id -nG "$USER" | grep -qw nixbld; then
        log_info "Adding $USER to nixbld group..."
        sudo usermod -a -G nixbld "$USER"
        needs_relogin=true
    fi
    
    # Add user to kvm group if it exists
    if [ "$(getent group kvm)" ]; then
        if ! id -nG "$USER" | grep -qw kvm; then
            log_info "Adding $USER to kvm group..."
            sudo usermod -a -G kvm "$USER"
            needs_relogin=true
        fi
    fi
    
    # Add user to libvirt group if it exists
    if [ "$(getent group libvirt)" ]; then
        if ! id -nG "$USER" | grep -qw libvirt; then
            log_info "Adding $USER to libvirt group..."
            sudo usermod -a -G libvirt "$USER"
            needs_relogin=true
        fi
    fi
    
    if [ "$needs_relogin" = true ]; then
        log_warning "User group memberships changed. Please log out and log back in for changes to take effect."
    fi
}

install_deps_fedora() {
    log_info "Installing system dependencies for Fedora..."
    
    local packages=(
        "bc"
        "vim"
        "git"
        "make"
        "qemu-img"
        "qemu-kvm"
        "libvirt"
        "pv"
        "rsync"
    )
    
    local missing_packages=()
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_success "All system dependencies are already installed"
    else
        log_info "Installing missing packages: ${missing_packages[*]}"
        if ! sudo dnf install -y "${missing_packages[@]}"; then
            log_error "Failed to install some packages"
            return 1
        fi
    fi
}

install_deps_debian() {
    log_info "Installing system dependencies for Debian/Ubuntu..."
    
    local packages=(
        "bc"
        "vim"
        "git"
        "make"
        "qemu-utils"
        "qemu-system-x86"
        "qemu-system-arm"
        "libvirt-daemon"
        "pv"
        "rsync"
        "curl"
    )
    
    log_info "Updating package list..."
    sudo apt-get update
    
    log_info "Installing packages: ${packages[*]}"
    if ! sudo apt-get install -y "${packages[@]}"; then
        log_error "Failed to install some packages"
        return 1
    fi
}

# Parse command line arguments
NIX_ONLY=false
DEPS_ONLY=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--nix-only)
            NIX_ONLY=true
            shift
            ;;
        -d|--deps-only)
            DEPS_ONLY=true
            shift
            ;;
        -c|--check)
            CHECK_ONLY=true
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

# Detect OS
detect_os

log_info "Detected OS: $OS"

# Check-only mode
if [ "$CHECK_ONLY" = true ]; then
    check_installation
    exit 0
fi

# Check disk space
check_disk_space

# Perform installation based on OS
case "$OS" in
    "Fedora Linux")
        if [ "$NIX_ONLY" != true ]; then
            install_deps_fedora
            setup_groups
        fi
        
        if [ "$DEPS_ONLY" != true ]; then
            install_nix_fedora
        fi
        ;;
        
    "Ubuntu"|"Debian")
        if [ "$NIX_ONLY" != true ]; then
            install_deps_debian
            setup_groups
        fi
        
        if [ "$DEPS_ONLY" != true ]; then
            install_nix_debian
        fi
        ;;
        
    "NixOS")
        log_info "NixOS detected - most tools should be available via Nix"
        log_info "Ensure qemu and libvirt are in your system configuration"
        ;;
        
    *)
        log_error "Unsupported OS: $OS"
        log_info "This script supports:"
        log_info "  - Fedora Linux"
        log_info "  - Ubuntu/Debian"
        log_info "  - NixOS (check only)"
        log_info ""
        log_info "For other systems, please manually install:"
        log_info "  - Nix package manager"
        log_info "  - QEMU/KVM"
        log_info "  - Git, Make, rsync"
        exit 1
        ;;
esac

echo
log_success "Setup completed!"
echo
log_info "Next steps:"
log_info "  1. Log out and log back in (if group memberships were changed)"
log_info "  2. Verify installation: $SCRIPT_NAME --check"
log_info "  3. Build an image: ./build-image.sh -f /path/to/your/flake"
log_info "  4. Deploy to a device: ./remote-deploy.sh -f /path/to/your/flake hostname config"

# Final check
echo
check_installation