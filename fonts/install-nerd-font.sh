#!/usr/bin/env bash
# Install JetBrainsMono Nerd Font for the current user (Linux).
# Run this on the machine that RENDERS your terminal (your local desktop,
# not a remote server you SSH into).
set -euo pipefail

# Its own subdirectory, so the ~40 font files stay together and the whole
# thing can be removed with a single rm -rf.
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
mkdir -p "$FONT_DIR"

TARBALL=$(mktemp -t JetBrainsMono.XXXXXX.tar.xz)
trap 'rm -f "$TARBALL"' EXIT

curl -fL -o "$TARBALL" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
tar -xf "$TARBALL" -C "$FONT_DIR"

if command -v fc-cache >/dev/null; then
    fc-cache -f "$FONT_DIR"
else
    echo "note: fc-cache not found; log out and back in to pick up the font."
fi

echo "Installed. Set your terminal font to 'JetBrainsMono Nerd Font'."
