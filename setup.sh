#!/usr/bin/env bash
# Bootstrap this machine from mysetup. Add new modules here as they land.
#
# Usage: ./setup.sh [--no-deps] [--core|--all] [--dry-run]
#
#   --no-deps  skip system package installation (configs only)
#   --core     install core packages only, no kitty/wl-clipboard
#   --all      install core + desktop packages
#   --dry-run  print the package command instead of running it
#
# With no flag, the desktop packages are installed only when a graphical
# session is detected.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

DEPS=1
DEP_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --no-deps) DEPS=0 ;;
        --core|--all|--dry-run) DEP_ARGS+=("$arg") ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [ "$DEPS" -eq 1 ]; then
    bash "$HERE/deps/install.sh" ${DEP_ARGS[@]+"${DEP_ARGS[@]}"}
    echo
else
    echo "Skipping dependency install (--no-deps)."
    echo
fi

bash "$HERE/claude/install.sh"
bash "$HERE/kitty/install.sh"
bash "$HERE/tmux/install.sh"

echo
echo "Fonts (run on the machine that renders your terminal):"
echo "  Linux:   bash fonts/install-nerd-font.sh"
echo "  Windows: powershell -ExecutionPolicy Bypass -File fonts/install-nerd-font.ps1"
