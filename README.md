# mysetup

Personal configs to bootstrap a new computer quickly.

## Quick start

```bash
git clone <this-repo> && cd mysetup
./setup.sh
```

## What's here

| Module | What it does |
|---|---|
| `claude/` | Claude Code status line: 3-line bar with Nerd Font icons, git info, and usage bars (5h / 7d / 7d-fable / context). `install.sh` copies the script to `~/.claude/` and merges the `statusLine` block into `~/.claude/settings.json` (backup kept). |
| `fonts/` | JetBrainsMono Nerd Font installers for Linux (`.sh`) and Windows (`.ps1`). The font must be installed on the machine that **renders** the terminal — your local desktop, not the server you SSH into. Then set the terminal font to "JetBrainsMono Nerd Font" (Windows Terminal: Settings > Profiles > Defaults > Appearance > Font face). |

## Notes

- Status line dependencies on the server: `bash`, `jq`, `curl`, `git`.
- The `7d-fable` usage bar reads the Claude.ai OAuth token from
  `~/.claude/.credentials.json` and queries an **undocumented** endpoint
  (`api.anthropic.com/api/oauth/usage`, cached 60s). It degrades silently
  if the endpoint changes or the machine uses API-key auth.
- Status line icons are Nerd Font glyphs; without the font they show as boxes.

## Planned

- oh-my-zsh config
- (add dotfiles/modules here as they accumulate)
