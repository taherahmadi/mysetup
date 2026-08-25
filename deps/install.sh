#!/usr/bin/env bash
# Install the system packages the other modules need.
#
# Two groups:
#   core     git curl jq tmux          - needed everywhere, servers included
#   desktop  kitty wl-clipboard        - only useful where a GUI renders the terminal
#
# The desktop group is auto-selected when a graphical session is detected;
# override with --core or --all. Packages already on PATH are never touched,
# so a manually installed kitty (~/.local/bin) is left alone.
set -euo pipefail

GROUP=auto
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --core)    GROUP=core ;;
        --all)     GROUP=all ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# ── Pick the package manager ──────────────────────
if   command -v apt-get >/dev/null; then PM=apt
elif command -v dnf     >/dev/null; then PM=dnf
elif command -v pacman  >/dev/null; then PM=pacman
elif command -v zypper  >/dev/null; then PM=zypper
else
    echo "No supported package manager found (apt/dnf/pacman/zypper)." >&2
    echo "Install these yourself, then re-run with --no-deps:" >&2
    echo "  git curl jq tmux kitty wl-clipboard" >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null; then
    SUDO="sudo"
else
    echo "Not root and sudo is missing; cannot install packages." >&2
    exit 1
fi

# ── Decide which groups to install ────────────────
if [ "$GROUP" = auto ]; then
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
        GROUP=all
        echo "Graphical session detected -> installing core + desktop packages."
    else
        GROUP=core
        echo "No graphical session detected -> installing core packages only (--all to override)."
    fi
fi

# "command package" pairs: we probe the command, install the package.
CORE="git:git curl:curl jq:jq tmux:tmux"
DESKTOP="kitty:kitty wl-copy:wl-clipboard"

WANTED="$CORE"
[ "$GROUP" = all ] && WANTED="$CORE $DESKTOP"

MISSING=""
for pair in $WANTED; do
    cmd="${pair%%:*}"
    pkg="${pair##*:}"
    if command -v "$cmd" >/dev/null; then
        echo "  ok       $cmd"
    else
        echo "  missing  $cmd (package: $pkg)"
        MISSING="$MISSING $pkg"
    fi
done

MISSING="${MISSING# }"
if [ -z "$MISSING" ]; then
    echo "All required packages are already present."
    exit 0
fi

echo
echo "Installing:$MISSING"
if [ "$DRY_RUN" -eq 1 ]; then
    case "$PM" in
        apt)    echo "[dry-run] $SUDO apt-get update && $SUDO apt-get install -y $MISSING" ;;
        dnf)    echo "[dry-run] $SUDO dnf install -y $MISSING" ;;
        pacman) echo "[dry-run] $SUDO pacman -S --needed --noconfirm $MISSING" ;;
        zypper) echo "[dry-run] $SUDO zypper install -y $MISSING" ;;
    esac
    exit 0
fi

case "$PM" in
    apt)    $SUDO apt-get update && $SUDO apt-get install -y $MISSING ;;
    dnf)    $SUDO dnf install -y $MISSING ;;
    pacman) $SUDO pacman -S --needed --noconfirm $MISSING ;;
    zypper) $SUDO zypper install -y $MISSING ;;
esac

echo "Dependencies installed."
