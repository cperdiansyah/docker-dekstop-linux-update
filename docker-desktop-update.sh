#!/bin/bash
# Docker Desktop Update Manager for Ubuntu
# Usage: ./docker-desktop-update.sh [--auto]

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
readonly DOWNLOAD_DIR="/tmp"
readonly DEB_PREFIX="docker-desktop"
readonly DOWNLOAD_URL="https://desktop.docker.com/linux/main/amd64/docker-desktop-latest-amd64.deb"
readonly GITHUB_API="https://api.github.com/repos/docker/desktop-linux/releases/latest"

# ─── Flags ────────────────────────────────────────────────────────────────────
AUTO_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()     { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

prompt_yes_no() {
    local message="$1"
    if [[ "$AUTO_MODE" == true ]]; then
        log "Auto mode: proceeding with '$message'"
        return 0
    fi
    read -p "$message (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# ─── Step 1: Check for Update ─────────────────────────────────────────────────
check_update() {
    log "Checking installed Docker Desktop version..."
    CURRENT_VERSION=$(dpkg -l 2>/dev/null | grep docker-desktop | awk '{print $3}' | cut -d'-' -f1 || echo "")

    if [[ -z "$CURRENT_VERSION" ]]; then
        warn "Docker Desktop is not currently installed."
    else
        log "Current version: $CURRENT_VERSION"
    fi

    log "Fetching latest version from Docker..."
    LATEST_VERSION=$(curl -sL "$DOWNLOAD_URL" -I | \
        grep -i "content-disposition" | \
        sed -n 's/.*docker-desktop-\([0-9.]*\)-.*/\1/p' || echo "")

    if [[ -z "$LATEST_VERSION" ]]; then
        log "Falling back to GitHub API..."
        LATEST_VERSION=$(curl -sL "$GITHUB_API" 2>/dev/null | \
            grep '"tag_name"' | \
            sed -n 's/.*"v\([0-9.]*\)".*/\1/p' || echo "")
    fi

    [[ -z "$LATEST_VERSION" ]] && error "Could not determine latest version."

    log "Latest version: $LATEST_VERSION"

    if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        success "Docker Desktop is already up to date ($CURRENT_VERSION). Nothing to do."
        exit 0
    fi

    if [[ -n "$CURRENT_VERSION" ]]; then
        log "Update available: $CURRENT_VERSION → $LATEST_VERSION"
    else
        log "Docker Desktop $LATEST_VERSION is available for installation."
    fi
}

# ─── Step 2: Download ─────────────────────────────────────────────────────────
download_update() {
    CACHED_DEB="$DOWNLOAD_DIR/${DEB_PREFIX}-${LATEST_VERSION}.deb"

    # Check for a previously downloaded file for the same version
    if [[ -f "$CACHED_DEB" ]]; then
        warn "Found existing download for version $LATEST_VERSION: $CACHED_DEB"
        warn "Skipping download — using cached file."
        return 0
    fi

    prompt_yes_no "Download Docker Desktop $LATEST_VERSION?" || {
        log "Download cancelled."
        exit 0
    }

    log "Downloading Docker Desktop $LATEST_VERSION to $CACHED_DEB..."
    curl --fail --progress-bar -o "$CACHED_DEB" "$DOWNLOAD_URL" || {
        rm -f "$CACHED_DEB"
        error "Download failed. Cleaned up incomplete file."
    }

    success "Download complete: $CACHED_DEB"
}

# ─── Step 3: Install ──────────────────────────────────────────────────────────
install_update() {
    prompt_yes_no "Install Docker Desktop $LATEST_VERSION now?" || {
        log "Installation skipped. The .deb file is saved at: $CACHED_DEB"
        log "You can install it later with: sudo apt-get install -y $CACHED_DEB"
        exit 0
    }

    log "Installing Docker Desktop $LATEST_VERSION..."
    sudo apt-get install -y "$CACHED_DEB"

    log "Cleaning up downloaded file..."
    rm -f "$CACHED_DEB"

    success "Docker Desktop updated to $LATEST_VERSION"
    log "Restart Docker Desktop to apply changes:"
    log "  systemctl --user restart docker-desktop"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_update    # sets CURRENT_VERSION, LATEST_VERSION
    download_update # sets CACHED_DEB; skips if already cached
    install_update  # uses CACHED_DEB; skips cleanup if install is deferred
}

main
