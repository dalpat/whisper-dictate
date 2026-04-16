#!/bin/bash
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $1"; }

REPO="https://github.com/dalpat/whisper-dictate.git"
INSTALL_DIR="$HOME/.local/share/whisper-dictate"

# Clone or update
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Updating existing installation..."
    git -C "$INSTALL_DIR" pull -q
else
    info "Cloning whisper-dictate..."
    git clone -q "$REPO" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/install.sh" "$INSTALL_DIR/toggle.sh"

info "Running installer..."
bash "$INSTALL_DIR/install.sh" "$@"
