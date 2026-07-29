#!/usr/bin/env bash
# Install the Claude Code status line on this machine.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null || { echo "jq is required (sudo apt install jq)"; exit 1; }
command -v curl >/dev/null || { echo "curl is required"; exit 1; }

mkdir -p "$HOME/.claude"
cp "$HERE/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"

STATUSLINE_CONFIG='{"type":"command","command":"~/.claude/statusline.sh","padding":1,"refreshInterval":5}'
if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$SETTINGS.bak"
    jq --argjson sl "$STATUSLINE_CONFIG" '.statusLine = $sl' "$SETTINGS" > "$SETTINGS.tmp"
    mv "$SETTINGS.tmp" "$SETTINGS"
    echo "statusLine merged into existing $SETTINGS (backup at $SETTINGS.bak)"
else
    printf '{\n  "statusLine": %s\n}\n' "$STATUSLINE_CONFIG" | jq . > "$SETTINGS"
    echo "created $SETTINGS"
fi

echo "Done. Restart Claude Code (or wait a refresh) to see the status line."
echo "Note: the 7d-fable usage bar needs a Claude.ai login (~/.claude/.credentials.json)."
