#!/bin/bash
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

HOTKEY="${1:-<Super><Alt>r}"
WHISPER_DIR="$HOME/whisper.cpp"
TOGGLE_SCRIPT="$(cd "$(dirname "$0")" && pwd)/toggle.sh"
MODEL="${WHISPER_MODEL:-tiny.en}"

# ─── 1. Dependencies ──────────────────────────────────────────────────────────
info "Installing dependencies..."
sudo apt update -qq
sudo apt install -y wl-clipboard alsa-utils libnotify-bin \
    git cmake build-essential &>/dev/null
info "Dependencies installed."

# ─── 2. Build whisper.cpp ─────────────────────────────────────────────────────
if [ -d "$WHISPER_DIR" ]; then
    warn "whisper.cpp already exists, skipping clone."
else
    info "Cloning whisper.cpp..."
    git clone https://github.com/ggml-org/whisper.cpp "$WHISPER_DIR" --depth=1 -q
fi

info "Building whisper.cpp (this takes ~2 min)..."
cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON &>/dev/null
cmake --build "$WHISPER_DIR/build" -j$(nproc) --config Release &>/dev/null
info "Build complete."

# ─── 3. Download Model ────────────────────────────────────────────────────────
if [ -f "$WHISPER_DIR/models/ggml-${MODEL}.bin" ]; then
    warn "Model ggml-${MODEL}.bin already exists, skipping."
else
    info "Downloading model: $MODEL..."
    bash "$WHISPER_DIR/models/download-ggml-model.sh" "$MODEL"
fi

# ─── 4. Register GNOME Hotkey ─────────────────────────────────────────────────
info "Registering GNOME hotkey: $HOTKEY"
chmod +x "$TOGGLE_SCRIPT"

BASE_KEY="org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
NEW_PATH="${CUSTOM_PATH}/custom99/"

EXISTING=$(gsettings get $BASE_KEY custom-keybindings \
    | tr -d "[]' " | tr ',' '\n' | grep -v '^$' | grep -v 'custom99')
ALL_PATHS=$(echo -e "$EXISTING\n${NEW_PATH}" \
    | grep -v '^$' | sort -u | sed "s|.*|'&'|" | paste -sd ',')

gsettings set $BASE_KEY custom-keybindings "[${ALL_PATHS}]"
gsettings set ${BASE_KEY}.custom-keybinding:${NEW_PATH} name    'Whisper Dictate'
gsettings set ${BASE_KEY}.custom-keybinding:${NEW_PATH} command "$TOGGLE_SCRIPT"
gsettings set ${BASE_KEY}.custom-keybinding:${NEW_PATH} binding "$HOTKEY"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ whisper-dictate ready!${NC}"
echo -e "  Hotkey : ${YELLOW}Super + Alt + R${NC}"
echo -e "  Press once  → starts recording"
echo -e "  Press again → transcribes, copies to clipboard"
echo -e "  Model  : ${YELLOW}${MODEL}${NC}  (override: WHISPER_MODEL=base.en ./install.sh)"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
