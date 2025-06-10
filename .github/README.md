# GitHub Actions CI/CD

This repository includes automated build and release workflows using GitHub Actions.

## Workflows

### 1. Build and Release (`release.yml`)
**Triggers:** 
- Push to `main` branch
- Pull request merged to `main`

**What it does:**
- Extracts version from `install.sh`
- Checks if release already exists
- Builds the installer using `build.sh`
- Creates a Git tag
- Generates comprehensive release notes
- Creates GitHub release with artifacts
- Uploads installer, source archive, and checksums

**Artifacts created:**
- `claude-desktop-linux-installer` (self-extracting installer)
- `claude-desktop-linux-v{version}-source.tar.gz` (source archive)
- `checksums.sha256` (file verification)

### 2. Build Test (`build-test.yml`)
**Triggers:**
- Pull requests to `main` (opened, updated, reopened)

**What it does:**
- Tests syntax of all scripts
- Runs build process
- Verifies artifacts are created correctly
- Validates checksums
- Tests installer extraction

### 3. Manual Release (`manual-release.yml`)
**Triggers:**
- Manual dispatch from GitHub Actions tab

**What it does:**
- Allows manual release creation
- Optional version override
- Optional pre-release marking
- Same build and release process as automatic workflow

## Usage

### Automatic Releases
1. Update `INSTALLER_VERSION` in `install.sh`
2. Commit and push to `main` branch
3. GitHub Actions automatically creates a release

### Manual Releases
1. Go to "Actions" tab in GitHub
2. Select "Manual Release" workflow
3. Click "Run workflow"
4. Optionally specify version override or mark as pre-release

### Version Management
Version is automatically detected from this line in `install.sh`:
```bash
INSTALLER_VERSION="1.0.0"
```

Update this version number to trigger new releases.

## Release Notes
Release notes are automatically generated and include:
- Commit messages since last release
- Installation instructions
- File descriptions
- Feature highlights
- System requirements

## Security
- Uses `GITHUB_TOKEN` for releases (no additional secrets needed)
- Validates file integrity with SHA256 checksums
- Tests build process before releasing

## File Structure
```
.github/
└── workflows/
    ├── release.yml          # Main release workflow
    ├── build-test.yml       # PR testing workflow
    └── manual-release.yml   # Manual release workflow
```
