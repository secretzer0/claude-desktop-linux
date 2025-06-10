#!/bin/bash

# Claude Desktop Linux Uninstaller
# Removes Claude Desktop integration files
# Version: 1.0.0

set -e

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

# Remove Claude Desktop integration files
remove_integration_files() {
    log_info "Removing Claude Desktop integration files..."
    
    # Remove launcher script
    if [ -f "/usr/local/bin/claude-desktop" ]; then
        sudo rm "/usr/local/bin/claude-desktop"
        log_info "Removed launcher script from /usr/local/bin"
    fi
    
    # Reset Chrome sandbox permissions in Nix store if present
    sandbox_files=$(find /nix/store -name "chrome-sandbox" -type f -perm -4000 2>/dev/null)
    if [ -n "$sandbox_files" ]; then
        echo "$sandbox_files" | while read -r sandbox_file; do
            if [ -f "$sandbox_file" ]; then
                # Reset to normal permissions (remove setuid)
                sudo chmod 755 "$sandbox_file" 2>/dev/null || true
                log_info "Reset permissions on $sandbox_file"
            fi
        done
    fi
    
    # Remove desktop entries
    if [ -f "$HOME/.local/share/applications/claude-desktop.desktop" ]; then
        rm "$HOME/.local/share/applications/claude-desktop.desktop"
        log_info "Removed application menu entry"
    fi
    
    if [ -f "$HOME/Desktop/claude-desktop.desktop" ]; then
        rm "$HOME/Desktop/claude-desktop.desktop"
        log_info "Removed desktop shortcut"
    fi
    
    # Remove icon
    if [ -f "$HOME/.local/share/icons/claude-ai-icon.svg" ]; then
        rm "$HOME/.local/share/icons/claude-ai-icon.svg"
        log_info "Removed Claude icon"
    fi
    
    # Clean up any desktop artifacts
    if [ -f "$HOME/Desktop/mimeinfo.cache" ]; then
        rm -f "$HOME/Desktop/mimeinfo.cache" 2>/dev/null || true
        log_info "Cleaned up desktop cache artifacts"
    fi
    
    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    log_success "Integration files removed"
}
# Remove system dependencies (full uninstall)
remove_system_dependencies() {
    log_warning "This will remove system-wide packages that may be used by other applications!"
    read -p "Are you sure you want to remove all system dependencies? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping system dependency removal"
        return
    fi
    
    log_info "Removing system dependencies..."
    
    # Remove Docker
    if command -v docker &> /dev/null; then
        sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo rm -f /etc/apt/sources.list.d/docker.list
        sudo rm -f /etc/apt/keyrings/docker.gpg
        log_info "Docker removed"
    fi
    
    # Remove Node.js (NodeSource version)
    if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
        sudo apt remove -y nodejs
        sudo rm -f /etc/apt/sources.list.d/nodesource.list
        log_info "Node.js removed"
    fi
    
    # Note: We don't remove build-essential, python3-dev, etc. as they're commonly needed
    log_info "Development tools (build-essential, python3-dev, etc.) were left installed"
    
    # Remove Nix
    if [ -d /nix ]; then
        log_info "Removing Nix..."
        sudo rm -rf /nix
        sudo rm -f /etc/profile.d/nix.sh
        sudo rm -f /etc/bash.bashrc.backup-before-nix
        sudo rm -f /etc/zshrc.backup-before-nix
        
        # Remove from user profile
        if [ -f "$HOME/.profile" ]; then
            sed -i '/nix/d' "$HOME/.profile"
        fi
        if [ -f "$HOME/.bashrc" ]; then
            sed -i '/nix/d' "$HOME/.bashrc"
        fi
        if [ -f "$HOME/.zshrc" ]; then
            sed -i '/nix/d' "$HOME/.zshrc"
        fi
        
        rm -rf "$HOME/.nix-profile" "$HOME/.nix-defexpr" "$HOME/.nix-channels"
        log_info "Nix removed"
    fi
    
    # Remove user from docker group
    sudo gpasswd -d "$USER" docker 2>/dev/null || true
    
    log_success "System dependencies removed"
}

# Main function
main() {
    echo
    log_info "Claude Desktop Linux Uninstaller"
    echo "======================================"
    echo
    
    # Parse arguments
    FULL_UNINSTALL=false
    for arg in "$@"; do
        case $arg in
            --full)
                FULL_UNINSTALL=true
                ;;
        esac
    done
    
    if [ "$FULL_UNINSTALL" = true ]; then
        log_warning "Full uninstall mode: Will remove integration files AND system dependencies"
    else
        log_info "Standard uninstall: Will remove integration files only"
        log_info "Use --full flag to also remove system dependencies"
    fi
    
    echo
    read -p "Continue with uninstallation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
    
    echo
    remove_integration_files
    
    if [ "$FULL_UNINSTALL" = true ]; then
        remove_system_dependencies
    fi
    
    echo
    log_success "Uninstallation completed!"
    
    if [ "$FULL_UNINSTALL" = true ]; then
        log_info "You may want to reboot to ensure all changes take effect"
    fi
}

# Run main function
main "$@"
