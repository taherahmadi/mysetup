#!/usr/bin/env bash
# Install JetBrainsMono Nerd Font for the current user (Linux).
# Run this on the machine that RENDERS your terminal (your local desktop,
# not a remote server you SSH into).
set -euo pipefail

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
cd "$FONT_DIR"

curl -fLO "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
tar -xf JetBrainsMono.tar.xz
rm JetBrainsMono.tar.xz
fc-cache -f

echo "Installed. Set your terminal font to 'JetBrainsMono Nerd Font'."
