#!/usr/bin/env bash
# Bootstrap this machine from mysetup. Add new modules here as they land.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

bash "$HERE/claude/install.sh"
bash "$HERE/kitty/install.sh"
bash "$HERE/tmux/install.sh"

echo
echo "Fonts (run on the machine that renders your terminal):"
echo "  Linux:   bash fonts/install-nerd-font.sh"
echo "  Windows: powershell -ExecutionPolicy Bypass -File fonts/install-nerd-font.ps1"
