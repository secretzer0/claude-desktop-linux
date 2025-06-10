#!/bin/bash

# Build script for Claude Desktop Linux
# Creates a self-contained binary installer
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALLER_NAME="claude-desktop-linux-installer"

# Create build directory
create_build_directory() {
    log_info "Creating build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/assets"
}

# Copy assets
copy_assets() {
    log_info "Copying assets..."
    
    # Copy the Claude icon
    if [ -f "$HOME/.local/share/icons/claude-ai-icon.svg" ]; then
        cp "$HOME/.local/share/icons/claude-ai-icon.svg" "$BUILD_DIR/assets/"
    else
        # Create placeholder icon
        cat > "$BUILD_DIR/assets/claude-ai-icon.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
<rect width="512" height="512" rx="115" fill="#D77655"/>
<text x="256" y="320" font-family="Arial,sans-serif" font-size="200" fill="white" text-anchor="middle">C</text>
</svg>
EOF
    fi
    
    # Copy documentation
    cp "$SCRIPT_DIR/README.md" "$BUILD_DIR/"
    
    log_success "Assets copied"
}
# Create self-extracting installer
create_installer() {
    log_info "Creating self-extracting installer..."
    
    # Create the installer script
    cat > "$BUILD_DIR/$INSTALLER_NAME" << 'EOF'
#!/bin/bash

# Claude Desktop Linux Self-Extracting Installer
# This is a self-contained installer that includes all necessary files

set -e

# Extract embedded files
SCRIPT_DIR="$(mktemp -d)"
ARCHIVE_LINE=$(grep -n "^# ARCHIVE_BELOW$" "$0" | cut -d: -f1)
ARCHIVE_LINE=$((ARCHIVE_LINE + 1))

# Extract the archive
tail -n +$ARCHIVE_LINE "$0" | base64 -d | tar -xzf - -C "$SCRIPT_DIR"

# Run the installer
cd "$SCRIPT_DIR"
exec ./install.sh "$@"

# This line marks the beginning of the archive
# ARCHIVE_BELOW
EOF
    
    # Create archive with all files
    cd "$SCRIPT_DIR"
    tar -czf "$BUILD_DIR/installer-archive.tar.gz" install.sh uninstall.sh assets/ README.md
    
    # Append base64-encoded archive to installer
    base64 "$BUILD_DIR/installer-archive.tar.gz" >> "$BUILD_DIR/$INSTALLER_NAME"
    
    # Make executable
    chmod +x "$BUILD_DIR/$INSTALLER_NAME"
    
    # Clean up
    rm "$BUILD_DIR/installer-archive.tar.gz"
    
    log_success "Self-extracting installer created: $BUILD_DIR/$INSTALLER_NAME"
}

# Create release package
create_release_package() {
    log_info "Creating release package..."
    
    # Get version from install.sh
    VERSION=$(grep 'INSTALLER_VERSION=' install.sh | cut -d'"' -f2)
    RELEASE_NAME="claude-desktop-linux-v$VERSION"
    
    # Create release directory
    mkdir -p "$BUILD_DIR/release"
    
    # Copy installer
    cp "$BUILD_DIR/$INSTALLER_NAME" "$BUILD_DIR/release/"
    
    # Create source archive
    cd "$SCRIPT_DIR"
    tar -czf "$BUILD_DIR/release/$RELEASE_NAME-source.tar.gz" \
        --exclude=build \
        --exclude=.git \
        .
    
    # Create checksums
    cd "$BUILD_DIR/release"
    sha256sum * > checksums.sha256
    
    log_success "Release package created in $BUILD_DIR/release/"
    log_info "Files created:"
    ls -la "$BUILD_DIR/release/"
}
# Main build function
main() {
    echo
    log_info "Claude Desktop Linux Builder"
    echo "================================="
    echo
    
    create_build_directory
    copy_assets
    create_installer
    create_release_package
    
    echo
    log_success "Build completed successfully!"
    echo
    log_info "Binary installer: $BUILD_DIR/$INSTALLER_NAME"
    log_info "Release files: $BUILD_DIR/release/"
    echo
    log_info "To test the installer:"
    echo "  $BUILD_DIR/$INSTALLER_NAME"
    echo
    log_info "To upload to GitHub releases:"
    echo "  1. Create a new release on GitHub"
    echo "  2. Upload all files from $BUILD_DIR/release/"
    echo "  3. Use the checksums.sha256 file to verify integrity"
    echo
}

# Run main function
main "$@"
