#!/usr/bin/env bash
# Install the tmux config on this machine.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.tmux.conf"

if [ -f "$DEST" ] && ! cmp -s "$HERE/tmux.conf" "$DEST"; then
    cp "$DEST" "$DEST.bak"
    echo "existing .tmux.conf backed up to $DEST.bak"
fi
cp "$HERE/tmux.conf" "$DEST"

echo "tmux config installed to $DEST"
echo "Reload in a running server with: tmux source-file ~/.tmux.conf"
