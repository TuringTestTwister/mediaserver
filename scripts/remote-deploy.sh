#!/usr/bin/env bash

set -euo pipefail

# Configuration
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(dirname "$(realpath "$0")")
# Default to current directory, can be overridden with -f/--flake-dir
FLAKE_DIR="${FLAKE_DIR:-$(pwd)}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_TEMP_DIR="/tmp/nixos-deploy-$$"

# SSH connection multiplexing configuration
SSH_CONTROL_DIR="$HOME/.ssh/control"
SSH_CONTROL_PATH="$SSH_CONTROL_DIR/%h_%p_%r"

# SSH configuration - supports both password and key authentication with connection multiplexing
SSH_BASE_CMD="ssh -o PasswordAuthentication=yes -o PubkeyAuthentication=yes -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPersist=600 -o ControlPath=$SSH_CONTROL_PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variable to track if SSH connection is established
SSH_CONNECTION_ESTABLISHED=false

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

# Setup SSH connection multiplexing
setup_ssh_multiplexing() {
    # Create control directory if it doesn't exist
    if [[ ! -d "$SSH_CONTROL_DIR" ]]; then
        mkdir -p "$SSH_CONTROL_DIR"
        chmod 700 "$SSH_CONTROL_DIR"
        log_info "Created SSH control directory: $SSH_CONTROL_DIR"
    fi
}

# Cleanup SSH connection
cleanup_ssh_connection() {
    if [[ "$SSH_CONNECTION_ESTABLISHED" == "true" ]]; then
        log_info "Cleaning up SSH connection..."
        $SSH_BASE_CMD -O exit "$REMOTE_HOST" 2>/dev/null || true
    fi
}

# Set up trap to cleanup SSH connection on script exit
trap cleanup_ssh_connection EXIT

# Function to prompt user about continuing without wireless secrets
prompt_continue_without_wireless() {
    echo
    log_warning "The wireless-secrets file does not exist at: $WIRELESS_SECRETS_FILE"
    log_warning "This means WiFi passwords will not be deployed to the remote host."
    echo
    read -p "Do you want to continue without setting up WiFi passwords? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
    log_info "Continuing deployment without wireless secrets..."
}

# Function to deploy wireless secrets
deploy_wireless_secrets() {
    # Wireless secrets file is expected in the flake directory
    WIRELESS_SECRETS_FILE="$FLAKE_DIR/wireless-secrets"
    
    if [[ ! -f "$WIRELESS_SECRETS_FILE" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "Would prompt user about missing wireless-secrets file"
            return 0
        else
            prompt_continue_without_wireless
            return 0
        fi
    fi

    log_info "Deploying wireless secrets from: $WIRELESS_SECRETS_FILE"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would copy $WIRELESS_SECRETS_FILE to remote host at /etc/nixos/wireless-secrets"
    else
        # Create /etc/nixos directory if it doesn't exist
        if ! $SSH_BASE_CMD "$REMOTE_HOST" "sudo mkdir -p /etc/nixos"; then
            log_error "Failed to create /etc/nixos directory on remote host"
            return 1
        fi

        # Copy the wireless secrets file to the temporary directory first
        if ! scp -o ControlPath="$SSH_CONTROL_PATH" "$WIRELESS_SECRETS_FILE" "$REMOTE_HOST:$REMOTE_TEMP_DIR/wireless-secrets"; then
            log_error "Failed to upload wireless-secrets file"
            return 1
        fi

        # Move it to the final location with appropriate permissions
        if ! $SSH_BASE_CMD "$REMOTE_HOST" "sudo cp '$REMOTE_TEMP_DIR/wireless-secrets' /etc/nixos/wireless-secrets && sudo chmod 600 /etc/nixos/wireless-secrets && sudo chown root:root /etc/nixos/wireless-secrets"; then
            log_error "Failed to install wireless-secrets file with proper permissions"
            return 1
        fi

        log_success "Wireless secrets deployed successfully"
    fi
}

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <hostname> <nixos-config>

Deploy a NixOS configuration by building locally and copying closure to remote host.

Arguments:
  hostname        Target hostname or IP address
  nixos-config    NixOS configuration name from flake (e.g., 'myserver' for .#nixosConfigurations.myserver)

Options:
  -u, --user USER           Remote user (default: root)
  -f, --flake-dir DIR       Flake directory (default: current directory)
  -d, --dry-run             Show what would be done without executing
  -k, --keep-result         Keep the local build result symlink
  -r, --reboot              Reboot after successful activation
  -h, --help               Show this help

Environment Variables:
  REMOTE_USER              Default remote user
  FLAKE_DIR               Default flake directory

Wireless Secrets:
  The script will look for a 'wireless-secrets' file in the flake directory
  and deploy it to /etc/nixos/wireless-secrets on the remote host. If the file doesn't
  exist, you'll be prompted whether to continue without WiFi password deployment.

Examples:
  # Deploy from current directory
  $SCRIPT_NAME myserver.lan myserver
  
  # Deploy from specific flake directory
  $SCRIPT_NAME -f /path/to/my-flake -u admin 192.168.1.100 homelab
  
  # Dry run with result keeping
  $SCRIPT_NAME --dry-run --keep-result server.example.com production

Note: This script uses SSH connection multiplexing to avoid repeated password prompts.
The initial connection will be reused for all subsequent SSH commands.
EOF
}

# Parse command line arguments
DRY_RUN=false
KEEP_RESULT=false
REBOOT_AFTER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -f|--flake-dir)
            FLAKE_DIR="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -k|--keep-result)
            KEEP_RESULT=true
            shift
            ;;
        -r|--reboot)
            REBOOT_AFTER=true
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
if [[ $# -lt 2 ]]; then
    log_error "Missing required arguments"
    usage
    exit 1
fi

HOSTNAME="$1"
NIXOS_CONFIG="$2"

# Ensure flake directory is absolute path
FLAKE_DIR=$(realpath "$FLAKE_DIR")

# Validate flake directory
if [[ ! -f "$FLAKE_DIR/flake.nix" ]]; then
    log_error "No flake.nix found in $FLAKE_DIR"
    exit 1
fi

FLAKE_REF="$FLAKE_DIR#nixosConfigurations.$NIXOS_CONFIG"
REMOTE_HOST="$REMOTE_USER@$HOSTNAME"

log_info "Starting NixOS closure deployment"
log_info "Flake: $FLAKE_REF"
log_info "Target: $REMOTE_HOST"
log_info "Flake directory: $FLAKE_DIR"

if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "DRY RUN MODE - No changes will be made"
fi

# Setup SSH connection multiplexing
setup_ssh_multiplexing

# Test SSH connectivity and establish master connection
log_info "Testing SSH connectivity to $REMOTE_HOST..."
log_info "Note: You may be prompted for a password if SSH keys are not configured"
log_info "This password will be reused for all subsequent SSH commands in this session"

if ! $SSH_BASE_CMD "$REMOTE_HOST" true; then
    log_error "Cannot connect to $REMOTE_HOST via SSH"
    log_error "Please ensure:"
    log_error "  - Host is reachable"
    log_error "  - SSH key authentication is set up OR password authentication is enabled"
    log_error "  - User $REMOTE_USER exists and has sudo privileges"
    exit 1
fi

SSH_CONNECTION_ESTABLISHED=true
log_success "SSH connectivity verified and master connection established"

# Build the system locally
log_info "Building NixOS configuration locally..."
BUILD_START=$(date +%s)

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Would run: nix build --no-link --print-out-paths '$FLAKE_REF.config.system.build.toplevel'"
    SYSTEM_PATH="/nix/store/dummy-system-path"
else
    # Capture both stdout and stderr separately
    BUILD_OUTPUT=$(mktemp)
    BUILD_STDERR=$(mktemp)

    if nix build --no-link --print-out-paths "$FLAKE_REF.config.system.build.toplevel" > "$BUILD_OUTPUT" 2> "$BUILD_STDERR"; then
        # Extract the store path (should be the only line starting with /nix/store/)
        SYSTEM_PATH=$(grep '^/nix/store/' "$BUILD_OUTPUT" | head -1)

        # Show any warnings that were sent to stderr
        if [[ -s "$BUILD_STDERR" ]]; then
            log_warning "Build warnings:"
            cat "$BUILD_STDERR" | sed 's/^/  /'
        fi
    else
        log_error "Build failed:"
        cat "$BUILD_STDERR" | tail -20  # Show last 20 lines of error
        log_error ""
        log_error "Troubleshooting tips:"
        log_error "  - Try: nix-collect-garbage && nix flake update"
        log_error "  - Check if you're cross-compiling (might need binary cache)"
        log_error "  - For full logs: nix log <drv-path-from-error>"
        rm -f "$BUILD_OUTPUT" "$BUILD_STDERR"
        exit 1
    fi

    # Cleanup temp files
    rm -f "$BUILD_OUTPUT" "$BUILD_STDERR"

    if [[ -z "$SYSTEM_PATH" ]]; then
        log_error "Build failed - no system path returned"
        exit 1
    fi

    if [[ ! "$SYSTEM_PATH" =~ ^/nix/store/ ]]; then
        log_error "Invalid system path returned: $SYSTEM_PATH"
        exit 1
    fi
fi

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))
log_success "Build completed in ${BUILD_TIME}s: $SYSTEM_PATH"

# Optionally create a result symlink for local reference
if [[ "$KEEP_RESULT" == "true" && "$DRY_RUN" == "false" ]]; then
    RESULT_LINK="$FLAKE_DIR/result-$NIXOS_CONFIG-$(date +%Y%m%d-%H%M%S)"
    ln -sf "$SYSTEM_PATH" "$RESULT_LINK"
    log_info "Created result symlink: $RESULT_LINK"
fi

# Copy closure to remote host
log_info "Copying closure to remote host..."
COPY_START=$(date +%s)

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Would run: nix-copy-closure --to '$REMOTE_HOST' '$SYSTEM_PATH'"
else
    # Set SSH command for nix-copy-closure using NIX_SSHOPTS with connection multiplexing
    export NIX_SSHOPTS="-o PasswordAuthentication=yes -o PubkeyAuthentication=yes -o ConnectTimeout=30 -o ControlMaster=auto -o ControlPersist=600 -o ControlPath=$SSH_CONTROL_PATH"

    if ! nix-copy-closure --to "$REMOTE_HOST" "$SYSTEM_PATH"; then
        log_error "Failed to copy closure to remote host"
        exit 1
    fi
fi

COPY_END=$(date +%s)
COPY_TIME=$((COPY_END - COPY_START))
log_success "Closure copied in ${COPY_TIME}s"

# Create temporary directory before deploying wireless secrets or activating system
if [[ "$DRY_RUN" == "false" ]]; then
    log_info "Creating temporary directory on remote host..."
    if ! $SSH_BASE_CMD "$REMOTE_HOST" "mkdir -p '$REMOTE_TEMP_DIR' && chmod 700 '$REMOTE_TEMP_DIR'"; then
        log_error "Failed to create temporary directory on remote host"
        exit 1
    fi
fi

# Deploy wireless secrets
if ! deploy_wireless_secrets; then
    log_error "Failed to deploy wireless secrets"
    if [[ "$DRY_RUN" == "false" ]]; then
        $SSH_BASE_CMD "$REMOTE_HOST" "rm -rf '$REMOTE_TEMP_DIR'" || true
    fi
    exit 1
fi

log_info "Activating new system configuration on remote host..."

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Would create activation script on remote"
    log_info "Would run activation script with system path: $SYSTEM_PATH"
else
    # Create and upload activation script
    log_info "Uploading activation script..."
    ACTIVATION_SCRIPT=$(cat << 'EOF'
#!/bin/bash
set -euo pipefail

SYSTEM_PATH="$1"

echo "Activating system: $SYSTEM_PATH"

# Verify system path exists
if [[ ! -d "$SYSTEM_PATH" ]]; then
    echo "Error: System path does not exist: $SYSTEM_PATH"
    exit 1
fi

# Set the system profile
echo "Setting system profile..."
nix-env --profile /nix/var/nix/profiles/system --set "$SYSTEM_PATH"

# Switch to the new configuration
echo "Switching to new configuration..."
"$SYSTEM_PATH/bin/switch-to-configuration" switch

echo "System activation completed successfully"
EOF
)

    if ! printf '%s\n' "$ACTIVATION_SCRIPT" | $SSH_BASE_CMD "$REMOTE_HOST" "cat > '$REMOTE_TEMP_DIR/activate.sh' && chmod +x '$REMOTE_TEMP_DIR/activate.sh'"; then
        log_error "Failed to upload activation script"
        $SSH_BASE_CMD "$REMOTE_HOST" "rm -rf '$REMOTE_TEMP_DIR'" || true
        exit 1
    fi

    # Verify script was created
    if ! $SSH_BASE_CMD "$REMOTE_HOST" "test -f '$REMOTE_TEMP_DIR/activate.sh' && test -x '$REMOTE_TEMP_DIR/activate.sh'"; then
        log_error "Activation script was not created properly"
        $SSH_BASE_CMD "$REMOTE_HOST" "ls -la '$REMOTE_TEMP_DIR/'" || true
        $SSH_BASE_CMD "$REMOTE_HOST" "rm -rf '$REMOTE_TEMP_DIR'" || true
        exit 1
    fi

    # Run activation script
    log_info "Running activation script..."
    if $SSH_BASE_CMD "$REMOTE_HOST" "cd '$REMOTE_TEMP_DIR' && sudo bash ./activate.sh '$SYSTEM_PATH'"; then
        log_success "System activation completed successfully"
    else
        log_error "System activation failed"
        # Show some debug info
        log_info "Debug information:"
        $SSH_BASE_CMD "$REMOTE_HOST" "ls -la '$REMOTE_TEMP_DIR/'" || true
        $SSH_BASE_CMD "$REMOTE_HOST" "cat '$REMOTE_TEMP_DIR/activate.sh'" || true
        $SSH_BASE_CMD "$REMOTE_HOST" "rm -rf '$REMOTE_TEMP_DIR'" || true
        exit 1
    fi

    # Cleanup temporary directory
    $SSH_BASE_CMD "$REMOTE_HOST" "rm -rf '$REMOTE_TEMP_DIR'" || log_warning "Failed to cleanup temporary directory"
fi

# Optional reboot
if [[ "$REBOOT_AFTER" == "true" ]]; then
    log_info "Rebooting remote system..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would reboot remote system"
    else
        $SSH_BASE_CMD "$REMOTE_HOST" "sudo reboot" || log_info "Reboot initiated (connection lost as expected)"
    fi
fi

# Summary
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - BUILD_START))

log_success "Deployment completed successfully!"
log_info "Total time: ${TOTAL_TIME}s (build: ${BUILD_TIME}s, copy: ${COPY_TIME}s)"
log_info "System path: $SYSTEM_PATH"

if [[ "$DRY_RUN" == "false" ]]; then
    log_info "You can now SSH to $HOSTNAME to verify the deployment"
    if [[ "$REBOOT_AFTER" == "false" ]]; then
        log_info "Consider rebooting the remote system to ensure all services are running the new configuration"
    fi
fi