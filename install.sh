#!/bin/bash

# Claude Desktop Linux Installer
# Automated installer for Claude Desktop on Ubuntu/Debian systems
# Version: 1.0.0
#
# Installation process:
# 1. Install system dependencies (Python, Node.js, Docker)
# 2. Install Nix package manager
# 3. Install and compile Claude Desktop via Nix flake (REQUIRED before Desktop Commander)
# 4. Install Desktop Commander
# 5. Create desktop integration with proper icon and Dash pinning
#
# Non-interactive features:
# - Nix installer uses --no-confirm flag
# - npm/npx commands use NPM_CONFIG_YES=true
# - apt uses DEBIAN_FRONTEND=noninteractive

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_VERSION="1.0.0"
MIN_UBUNTU_VERSION="20.04"
REQUIRED_SPACE_GB=5

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
# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root!"
        log_info "Please run as a regular user. Sudo will be used when needed."
        exit 1
    fi
}

# System compatibility check
check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    # Check if it's Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        log_error "This installer is designed for Ubuntu/Debian systems with apt package manager"
        exit 1
    fi
    
    # Get OS information
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    else
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    log_info "Detected: $OS_NAME $OS_VERSION"
    
    # Check minimum Ubuntu version
    if [[ "$OS_NAME" == *"Ubuntu"* ]]; then
        if dpkg --compare-versions "$OS_VERSION" "lt" "$MIN_UBUNTU_VERSION"; then
            log_error "Ubuntu $OS_VERSION is not supported. Minimum version: $MIN_UBUNTU_VERSION"
            exit 1
        fi
    fi
    
    # Check available disk space
    available_space=$(df "$HOME" | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$available_space" -lt "$REQUIRED_SPACE_GB" ]; then
        log_error "Insufficient disk space. Required: ${REQUIRED_SPACE_GB}GB, Available: ${available_space}GB"
        exit 1
    fi
    
    log_success "System compatibility check passed"
}

# Check if packages are installed
check_package_installed() {
    dpkg -l "$1" &> /dev/null
}
# Install system dependencies
install_system_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package list
    log_info "Updating package list..."
    sudo apt update
    
    # Install basic development tools
    log_info "Installing development tools..."
    sudo apt install -y python3-dev python3-pip build-essential git curl wget attr
    
    # Install Node.js via NodeSource
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        log_info "Installing Node.js and npm..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
    else
        log_info "Node.js and npm already installed"
    fi
    
    log_success "System dependencies installed"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        return
    fi
    
    log_info "Installing Docker..."
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    sudo apt install -y ca-certificates gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    # Activate docker group membership immediately (no logout required)
    if command -v newgrp &> /dev/null; then
        log_info "Activating Docker group membership..."
        # Note: newgrp starts a new shell, so we'll just inform the user
        log_info "Docker group added - Docker commands should work immediately"
    fi
    
    log_success "Docker installed and user added to docker group."
}
# Install Nix package manager
install_nix() {
    if command -v nix &> /dev/null; then
        log_info "Nix already installed"
        return
    fi
    
    log_info "Installing Nix package manager..."
    
    # Install Nix using the Determinate Nix Installer with automatic confirmation
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    
    # Source Nix environment immediately after installation - try multiple locations
    if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        log_info "Sourcing Nix daemon environment..."
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        export PATH="/nix/var/nix/profiles/default/bin:$PATH"
    elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        log_info "Sourcing Nix profile environment..."
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
        export PATH="$HOME/.nix-profile/bin:$PATH"
    else
        log_warning "Could not find Nix environment script"
        # Try to manually set up the environment
        if [ -d "/nix/var/nix/profiles/default/bin" ]; then
            export PATH="/nix/var/nix/profiles/default/bin:$PATH"
        elif [ -d "$HOME/.nix-profile/bin" ]; then
            export PATH="$HOME/.nix-profile/bin:$PATH"
        fi
    fi
    
    # Also ensure .local/bin is in PATH for user scripts
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        log_info "Added ~/.local/bin to PATH"
    fi
    
    # Verify Nix is now available
    if command -v nix &> /dev/null; then
        log_success "Nix installed and environment configured"
        log_info "Nix found at: $(which nix)"
        log_info "Current PATH: $PATH"
    else
        log_error "Nix installation failed or environment not properly configured"
        log_info "PATH is: $PATH"
        log_info "Please run: source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        exit 1
    fi
}

# Enhanced progress display with status bar
show_nix_progress() {
    local temp_output="$1"
    local process_name="$2"
    local pid="$3"
    
    # If VERBOSE is set, just tail the output instead of status bar
    if [ "$VERBOSE" = "true" ]; then
        echo "[$process_name] Starting... (verbose mode)"
        tail -f "$temp_output" 2>/dev/null &
        local tail_pid=$!
        wait "$pid"
        kill $tail_pid 2>/dev/null || true
        echo "[$process_name] ✓ Completed"
        return
    fi
    
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local spin_idx=0
    local last_status=""
    local download_count=0
    local build_count=0
    
    echo -n "[$process_name] Starting..."
    
    while kill -0 "$pid" 2>/dev/null; do
        # Get current spinner character
        local spin_char="${spinner:$spin_idx:1}"
        spin_idx=$(( (spin_idx + 1) % ${#spinner} ))
        
        # Parse the output for status updates
        if [ -f "$temp_output" ]; then
            local latest_line=$(tail -1 "$temp_output" 2>/dev/null || echo "")
            local status=""
            
            # Parse different types of Nix output
            if echo "$latest_line" | grep -q "copying path.*from.*cache"; then
                download_count=$((download_count + 1))
                status="Downloading dependencies ($download_count packages)..."
            elif echo "$latest_line" | grep -q "building.*drv"; then
                build_count=$((build_count + 1))
                status="Compiling packages ($build_count components)..."
            elif echo "$latest_line" | grep -q "unpacking.*source"; then
                status="Unpacking source code..."
            elif echo "$latest_line" | grep -q "configuring"; then
                status="Configuring build..."
            elif echo "$latest_line" | grep -q "building"; then
                status="Building components..."
            elif echo "$latest_line" | grep -q "installing"; then
                status="Installing packages..."
            elif echo "$latest_line" | grep -q "post-installation"; then
                status="Post-installation setup..."
            fi
            
            # Update status if we have something new
            if [ -n "$status" ] && [ "$status" != "$last_status" ]; then
                last_status="$status"
            fi
        fi
        
        # Display current status with spinner
        printf "\r\033[K[$process_name] $spin_char $last_status"
        sleep 0.2
    done
    
    # Clear the line and show completion
    printf "\r\033[K"
    echo "[$process_name] ✓ Completed"
}

# Ensure Nix environment is properly set up
ensure_nix_environment() {
    # Source Nix environment if not already available
    if ! command -v nix &> /dev/null; then
        log_info "Nix command not found, setting up environment..."
        
        # Try to source Nix environment
        if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
            log_info "Sourcing Nix daemon environment..."
            . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
            export PATH="/nix/var/nix/profiles/default/bin:$PATH"
        elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
            log_info "Sourcing Nix profile environment..."
            . "$HOME/.nix-profile/etc/profile.d/nix.sh"
            export PATH="$HOME/.nix-profile/bin:$PATH"
        else
            # Try manual PATH setup
            if [ -d "/nix/var/nix/profiles/default/bin" ]; then
                export PATH="/nix/var/nix/profiles/default/bin:$PATH"
            elif [ -d "$HOME/.nix-profile/bin" ]; then
                export PATH="$HOME/.nix-profile/bin:$PATH"
            fi
        fi
    fi
    
    # Ensure .local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Verify Nix is available
    if ! command -v nix &> /dev/null; then
        log_error "Nix command still not available after environment setup"
        log_info "Current PATH: $PATH"
        log_info "Please manually run: source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        return 1
    fi
    
    return 0
}

# Setup Chrome sandbox for Claude Desktop
setup_chrome_sandbox() {
    log_info "Setting up Chrome sandbox for Claude Desktop..."
    
    # Ensure Nix environment is available
    if ! ensure_nix_environment; then
        log_warning "Cannot set up Nix environment for sandbox setup"
        return 1
    fi
    
    export NIXPKGS_ALLOW_UNFREE=1
    
    # Build the Claude Desktop derivation without running it to get the sandbox binary
    log_info "Downloading Electron components to extract sandbox binary..."
    echo "This may take several minutes depending on your internet connection..."
    
    # Build with progress status bar
    temp_output="/tmp/nix-build-output-$$"
    (nix build github:k3d3/claude-desktop-linux-flake --impure --extra-experimental-features nix-command --extra-experimental-features flakes --print-out-paths --no-link > "$temp_output" 2>&1) &
    nix_pid=$!
    
    show_nix_progress "$temp_output" "Package Build" "$nix_pid"
    wait $nix_pid
    nix_result=$?
    
    if [ $nix_result -eq 0 ]; then
        store_path=$(cat "$temp_output" | tail -1)
        log_success "Claude Desktop package built successfully"
    else
        log_warning "Nix build failed, showing output:"
        cat "$temp_output"
        store_path=""
    fi
    
    rm -f "$temp_output"
    
    if [ -n "$store_path" ] && [ -d "$store_path" ]; then
        # Find the Electron sandbox binary in the store
        sandbox_source=$(find "$store_path" -name "chrome-sandbox" -type f 2>/dev/null | head -1)
        
        if [ -n "$sandbox_source" ] && [ -f "$sandbox_source" ]; then
            # Set proper permissions on the Nix store location
            log_info "Setting proper permissions on chrome-sandbox at: $sandbox_source"
            
            # Set proper permissions (setuid root) on the actual file
            if sudo chown root:root "$sandbox_source" && sudo chmod 4755 "$sandbox_source"; then
                log_success "Chrome sandbox configured with proper permissions at $sandbox_source"
                
                return 0
            else
                log_warning "Could not set proper permissions on sandbox binary"
                # Reset permissions to default if setting failed
                sudo chown "$USER:$USER" "$sandbox_source" 2>/dev/null || true
                sudo chmod 755 "$sandbox_source" 2>/dev/null || true
            fi
        else
            log_info "Chrome sandbox binary not found in Nix store, will use fallback method"
        fi
    else
        log_info "Could not build Claude Desktop package, will use fallback method"
    fi
    
    return 1
}

# Install Claude Desktop via Nix
install_claude_desktop() {
    log_info "Installing Claude Desktop via Nix flake..."
    
    # Ensure Nix environment is available
    if ! ensure_nix_environment; then
        log_error "Cannot set up Nix environment - Claude Desktop installation failed"
        exit 1
    fi
    
    log_info "Nix command found at: $(which nix)"
    log_info "Current PATH: $PATH"
    
    # Skip sandbox setup - let it fail first to get the binary
    sandbox_setup_success=false
    
    # Install Claude Desktop (this compiles and caches all required components)
    export NIXPKGS_ALLOW_UNFREE=1
    
    log_info "This may take several minutes to download and compile Claude Desktop..."
    log_info "Compiling: Claude Desktop"
    echo ""
    
    # Run Nix with status bar progress display
    temp_output="/tmp/claude-nix-output-$$"
    
    (nix run github:k3d3/claude-desktop-linux-flake --impure --extra-experimental-features nix-command --extra-experimental-features flakes > "$temp_output" 2>&1) &
    nix_pid=$!
    
    show_nix_progress "$temp_output" "Claude Desktop" "$nix_pid"
    wait $nix_pid || true
    
    # Read the captured output to extract sandbox path
    nix_output=$(cat "$temp_output" 2>/dev/null || true)
    rm -f "$temp_output"
    
    # Extract the chrome-sandbox path from the error message
    sandbox_path=$(echo "$nix_output" | grep -o '/nix/store/[^/]*/libexec/electron/chrome-sandbox' | head -1)
    
    if [ -n "$sandbox_path" ] && [ -f "$sandbox_path" ]; then
        log_success "Found chrome-sandbox binary at: $sandbox_path"
        log_info "Setting proper permissions on chrome-sandbox..."
        
        # Set proper ownership and permissions on the actual file
        if sudo chown root:root "$sandbox_path" && sudo chmod 4755 "$sandbox_path"; then
            log_success "Chrome sandbox configured with proper permissions"
            sandbox_setup_success=true
        else
            log_error "Failed to set proper permissions on chrome-sandbox"
            exit 1
        fi
    else
        log_error "Could not find chrome-sandbox binary in Nix output"
        log_info "Claude Desktop may not have been built properly"
        exit 1
    fi
    
    nix run github:k3d3/claude-desktop-linux-flake --impure --extra-experimental-features nix-command --extra-experimental-features flakes &
    nix_pid=$!
    
    # Wait for launch
    log_info "Waiting for Claude Desktop to launch..."
    sleep 15
    
    # Check if Claude Desktop started and terminate the GUI
    if pgrep -f "claude-desktop.*app.asar" > /dev/null || pgrep -f "electron.*claude" > /dev/null; then
        log_success "Claude Desktop launched successfully!"
        log_info "Stopping GUI to continue installation..."
        pkill -f "claude-desktop.*app.asar" 2>/dev/null || true
        pkill -f "electron.*claude" 2>/dev/null || true
    else
        log_warning "Claude Desktop may not have launched visibly (this can be normal)"
    fi
    
    # Wait for nix process to complete
    wait $nix_pid 2>/dev/null || true
    
    echo ""
    log_success "Claude Desktop installed and compiled successfully"
}

# Install Desktop Commander
install_desktop_commander() {
    log_info "Installing Desktop Commander..."
    echo "Setting up Claude Desktop integration with system tools..."
    
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        # Set npm to non-interactive mode and run setup
        export NPM_CONFIG_YES=true
        echo "Running Desktop Commander setup (this may take a moment)..."
        npx @wonderwhy-er/desktop-commander@latest setup --no-interaction 2>/dev/null || \
        npx @wonderwhy-er/desktop-commander@latest setup --yes 2>/dev/null || \
        echo "y" | npx @wonderwhy-er/desktop-commander@latest setup
        log_success "Desktop Commander installed"
    else
        log_error "Node.js/npm not available for Desktop Commander installation"
        return 1
    fi
}
# Create desktop integration files
create_desktop_integration() {
    log_info "Creating desktop integration files..."
    
    # Create directories
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.local/share/applications"
    mkdir -p "$HOME/.local/share/icons"
    
    # Download Claude icon if not present
    if [ ! -f "$HOME/.local/share/icons/claude-ai-icon.svg" ]; then
        log_info "Downloading Claude AI icon..."
        if [ -f "$SCRIPT_DIR/assets/claude-ai-icon.svg" ]; then
            cp "$SCRIPT_DIR/assets/claude-ai-icon.svg" "$HOME/.local/share/icons/"
        else
            # Download from GitHub
            log_info "Fetching Claude icon from GitHub..."
            if curl -fsSL "https://raw.githubusercontent.com/secretzer0/claude-desktop-linux/main/assets/claude-ai-icon.svg" -o "$HOME/.local/share/icons/claude-ai-icon.svg"; then
                log_success "Claude icon downloaded"
            else
                # Fallback: create a simple placeholder icon
                log_warning "Could not download icon, using fallback"
                cat > "$HOME/.local/share/icons/claude-ai-icon.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
<rect width="512" height="512" rx="115" fill="#D77655"/>
<text x="256" y="320" font-family="Arial,sans-serif" font-size="200" fill="white" text-anchor="middle">C</text>
</svg>
EOF
            fi
        fi
    fi
    
    # Create launcher script
    sudo tee "/usr/local/bin/claude-desktop" > /dev/null << 'EOF'
#!/bin/bash

# Claude Desktop Launcher Script
# This script launches Claude Desktop using the Nix flake

export NIXPKGS_ALLOW_UNFREE=1

# Change to home directory to ensure consistent working directory
cd "$HOME"

# Source Nix environment if available
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Check if Claude Desktop is already running
if pgrep -f "claude-desktop.*app.asar" > /dev/null; then
    echo "Claude Desktop is already running. Bringing to front..."
    # Try to bring the existing window to front
    if command -v wmctrl &> /dev/null; then
        wmctrl -a "Claude" 2>/dev/null || true
    elif command -v xdotool &> /dev/null; then
        xdotool search --class "Claude" windowactivate 2>/dev/null || true
    fi
    exit 0
fi

# Launch Claude Desktop (exit with error if sandbox fails)
nix_output=$(nix run github:k3d3/claude-desktop-linux-flake --impure --extra-experimental-features nix-command --extra-experimental-features flakes 2>&1)
nix_exit_code=$?

if [ $nix_exit_code -ne 0 ]; then
    echo "ERROR: Claude Desktop failed to launch with Chrome sandbox." >&2
    echo "This is a security requirement and claude-desktop will not run without it." >&2
    echo "" >&2
    
    # Extract the chrome-sandbox path from the error message
    sandbox_path=$(echo "$nix_output" | grep -o '/nix/store/[^/]*/libexec/electron/chrome-sandbox' | head -1)
    
    if [ -n "$sandbox_path" ]; then
        echo "Please ensure chrome-sandbox has proper setuid permissions:" >&2
        echo "  sudo chown root:root '$sandbox_path'" >&2
        echo "  sudo chmod 4755 '$sandbox_path'" >&2
    else
        echo "Please ensure chrome-sandbox is properly installed with setuid permissions." >&2
        echo "Find the chrome-sandbox location with:" >&2
        echo "  find /nix/store -name 'chrome-sandbox' -type f" >&2
        echo "Then set permissions with:" >&2
        echo "  sudo chown root:root <path-to-chrome-sandbox>" >&2
        echo "  sudo chmod 4755 <path-to-chrome-sandbox>" >&2
    fi
    
    exit 1
fi
EOF
    
    sudo chmod +x "/usr/local/bin/claude-desktop"
}
# Create desktop entry
create_desktop_entry() {
    log_info "Creating desktop entry..."
    
    cat > "$HOME/.local/share/applications/claude-desktop.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Claude Desktop
Comment=Claude AI Desktop Application
GenericName=AI Assistant
Exec=/usr/local/bin/claude-desktop
Icon=$HOME/.local/share/icons/claude-ai-icon.svg
StartupNotify=true
NoDisplay=false
MimeType=
Categories=Office;Productivity;
Keywords=AI;Assistant;Claude;Anthropic;
StartupWMClass=Claude
Terminal=false
SingleMainWindow=true
Actions=new-window;

[Desktop Action new-window]
Name=New Window
Exec=/usr/local/bin/claude-desktop
EOF
    
    chmod +x "$HOME/.local/share/applications/claude-desktop.desktop"
    
    # Create desktop shortcut
    cp "$HOME/.local/share/applications/claude-desktop.desktop" "$HOME/Desktop/"
    
    # Mark desktop shortcut as trusted - Ubuntu 20.04+ requires this
    desktop_file="$HOME/Desktop/claude-desktop.desktop"
    
    # Make sure it's executable first (required)
    chmod +x "$desktop_file"
    
    # Most reliable method for Ubuntu: Use gio info command to check and set trust
    if command -v gio &> /dev/null; then
        # Check if already trusted
        if ! gio info "$desktop_file" 2>/dev/null | grep -q "metadata::trusted"; then
            gio set "$desktop_file" metadata::trusted true 2>/dev/null || true
        fi
        # Force trust via alternate method
        gio set "$desktop_file" metadata::nautilus-icon-position '' 2>/dev/null || true
        log_info "Applied trust metadata via gio"
    fi
    
    # Alternative method: Direct file attribute (works on many systems)
    if command -v setfattr &> /dev/null; then
        setfattr -n user.xdg.origin.url -v "file://$desktop_file" "$desktop_file" 2>/dev/null || true
        setfattr -n user.mime_type -v "application/x-desktop" "$desktop_file" 2>/dev/null || true
    fi
    
    # Force desktop refresh to recognize the new trusted file
    if command -v nautilus &> /dev/null; then
        nautilus -q 2>/dev/null || true  # Quit nautilus to force refresh
    fi
    
    # Update desktop database to refresh (but not on Desktop folder to avoid artifacts)
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        # Note: Don't run update-desktop-database on Desktop folder as it creates mimeinfo.cache artifacts
    fi
    
    # Pin Claude Desktop to the Dash (GNOME's left sidebar dock)
    if command -v gsettings &> /dev/null; then
        log_info "Pinning Claude Desktop to Dash..."
        
        # Get current favorites
        current_favorites=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo "[]")
        log_info "Current Dash favorites: $current_favorites"
        
        # Check if claude-desktop.desktop is already in favorites
        if [[ "$current_favorites" != *"claude-desktop.desktop"* ]]; then
            # Remove the closing bracket and add our app
            if [[ "$current_favorites" == "[]" ]]; then
                # Empty list, just add our app
                new_favorites="['claude-desktop.desktop']"
            else
                # Add to existing list - remove last bracket, add comma and our app, then close bracket
                new_favorites=$(echo "$current_favorites" | sed "s/]/, 'claude-desktop.desktop']/")
            fi
            
            log_info "Setting new Dash favorites: $new_favorites"
            
            # Set the new favorites list
            if gsettings set org.gnome.shell favorite-apps "$new_favorites" 2>/dev/null; then
                log_success "Claude Desktop added to Dash favorites"
                
                # Wait a moment for gsettings to propagate
                sleep 1
                
                # Force GNOME Shell to reload the Dash using multiple approaches
                if command -v gdbus &> /dev/null; then
                    # Try different Dash refresh methods (GNOME Shell internal structure varies)
                    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "Main.overview._dash._redisplay();" 2>/dev/null || \
                    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "Main.overview.dash._redisplay();" 2>/dev/null || \
                    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "Main.overview.viewSelector._dash._redisplay();" 2>/dev/null || \
                    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "Main.overview._overview._dash._redisplay();" 2>/dev/null || \
                    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "Main.layoutManager._updateHotCorners(); Main.overview._dash._queueRedisplay();" 2>/dev/null || true
                    log_info "Triggered Dash refresh via multiple methods"
                fi
                
                # Additional method: Try to refresh the entire shell overview
                if command -v gdbus &> /dev/null; then
                    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "Main.overview._overview.controls._dashSpacer.queue_relayout();" 2>/dev/null || true
                fi
                
                log_info "Dash should refresh automatically, or try pressing Super key to open Activities"
                log_info "If still not visible, press Alt+F2 and type 'r' to restart GNOME Shell"
            else
                log_warning "Could not pin to Dash automatically"
                log_info "You can pin manually by right-clicking the app in Activities and selecting 'Pin to Dash'"
            fi
        else
            log_info "Claude Desktop already in Dash favorites"
        fi
    else
        log_info "gsettings not available - you can pin Claude Desktop manually from the Activities view"
    fi
    
    # Clean up any mimeinfo.cache artifacts that may have appeared on desktop
    if [ -f "$HOME/Desktop/mimeinfo.cache" ]; then
        rm -f "$HOME/Desktop/mimeinfo.cache" 2>/dev/null || true
        log_info "Cleaned up desktop cache artifacts"
    fi
    
    log_success "Desktop shortcut created and configured"
    
    # Method 3: Use gsettings to configure Nautilus behavior
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.nautilus.preferences executable-text-activation 'launch' 2>/dev/null || true
        log_info "Configured Nautilus to launch executable files"
    fi
    
    # Method 4: Alternative approach - modify the desktop file to be more trusted
    # Add a specific key that Ubuntu recognizes
    if grep -q "^StartupNotify=" "$desktop_file"; then
        sed -i '/^StartupNotify=/a X-GNOME-Autostart-enabled=true' "$desktop_file"
    fi
    
    log_success "Desktop shortcut created and configured for immediate use"
    
    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$HOME/.local/share/applications"
    fi
    
    log_success "Desktop integration created"
}

# Main installation function
main() {
    # Parse command line arguments
    AUTO_INSTALL=false
    VERBOSE=false
    for arg in "$@"; do
        case $arg in
            --auto|--yes|-y)
                AUTO_INSTALL=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
        esac
    done
    
    echo
    log_info "Claude Desktop Linux Installer v$INSTALLER_VERSION"
    echo "=================================================="
    echo
    
    check_not_root
    check_system_compatibility
    
    echo
    log_info "This installer will:"
    echo "  • Install system dependencies (Python, Node.js, Docker, Nix)"
    echo "  • Set up Claude Desktop via Nix flake"
    echo "  • Create desktop integration with proper icon"
    echo "  • Install Desktop Commander"
    echo
    
    if [ "$VERBOSE" = "true" ]; then
        log_info "Verbose mode enabled - full compilation output will be shown"
        echo
    fi
    
    # Check if we should skip confirmation
    if [ "$AUTO_INSTALL" = true ]; then
        log_info "Auto-install mode enabled, proceeding with installation..."
    else
        # Ask for confirmation (works perfectly with bash <(curl ...) pattern)
        echo -n "Continue with installation? [Y/n] "
        read -r REPLY
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
    
    echo
    
    # Set environment variables for non-interactive installations
    export DEBIAN_FRONTEND=noninteractive
    export NPM_CONFIG_YES=true
    export CI=true
    
    install_system_dependencies
    install_docker
    install_nix
    install_claude_desktop
    install_desktop_commander
    create_desktop_integration
    create_desktop_entry
    
    echo
    log_success "Installation completed successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Look for 'Claude Desktop' in your application menu"
    echo "  2. Check your Dash (left sidebar) - Claude Desktop should be pinned there"
    echo "  3. If not in Dash: Open Activities → search 'Claude Desktop' → right-click → 'Pin to Dash'"
    echo "  4. Or run from terminal: claude-desktop"
    echo "  5. Desktop shortcut should be ready to use"
    echo
    log_info "Troubleshooting:"
    echo "  • If Dash doesn't update: Press Alt+F2, type 'r', press Enter to restart GNOME Shell"
    echo "  • If Nix commands fail: run 'source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'"
    echo "  • If Claude Desktop shows sandbox errors: the claude-desktop script will show the exact path and commands needed"
    echo "  • If desktop shortcut shows 'Untrusted' warning: right-click and select 'Allow Launching'"
    echo "  • If Docker commands fail: you may need to log out and back in once"
    echo "  • For other issues: check the README.md file"
    echo
}

# Run main function
main "$@"
