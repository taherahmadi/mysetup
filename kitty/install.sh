#!/usr/bin/env bash
# Install the kitty terminal config on this machine.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/kitty/kitty.conf"

mkdir -p "$(dirname "$DEST")"
if [ -f "$DEST" ] && ! cmp -s "$HERE/kitty.conf" "$DEST"; then
    cp "$DEST" "$DEST.bak"
    echo "existing kitty.conf backed up to $DEST.bak"
fi
cp "$HERE/kitty.conf" "$DEST"

echo "kitty config installed to $DEST"
echo "Note: needs JetBrainsMono Nerd Font (see fonts/). Reload with ctrl+shift+F5."
