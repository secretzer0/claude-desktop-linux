# Claude Desktop Linux

Automated installer for Claude Desktop on Ubuntu/Debian with proper desktop integration and DesktopCommander.

## Quick Install

**One-line install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/secretzer0/claude-desktop-linux/main/install.sh)
```

**Auto install (no prompts):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/secretzer0/claude-desktop-linux/main/install.sh) --auto
```

**Binary installer:**
```bash
wget https://github.com/secretzer0/claude-desktop-linux/releases/latest/download/claude-desktop-linux-installer
chmod +x claude-desktop-linux-installer
./claude-desktop-linux-installer
```

## What it installs

- All dependencies (Python, Node.js, Docker, Nix)
- Claude Desktop via Nix flake
- Desktop launcher with proper icon
- Application menu integration
- Desktop Commander

## Uninstall

**Remove integration only:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/secretzer0/claude-desktop-linux/main/uninstall.sh)
```

**Remove everything:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/secretzer0/claude-desktop-linux/main/uninstall.sh) --full
```

## Requirements

- Ubuntu 24.04 (tested)
- May work on other Ubuntu/Debian systems

## License

[MIT](LICENSE)

## Credits

- [Claude Desktop Linux Flake](https://github.com/k3d3/claude-desktop-linux-flake) by k3d3
- [DesktopCommander](https://github.com/wonderwhy-er/desktop-commander) by wonderwhy-er
- [Nix Package Manager](https://nixos.org/) by the NixOS community
