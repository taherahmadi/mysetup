# mysetup

Personal configs to bootstrap a new computer quickly.

## Quick start

```bash
git clone <this-repo> && cd mysetup
./setup.sh
```

`setup.sh` installs system packages first, then the configs. Flags:

| Flag | Effect |
|---|---|
| *(none)* | Installs core packages, plus the desktop ones when a graphical session is detected. |
| `--no-deps` | Configs only, no package installation — use on a machine where you can't or won't run `apt`. |
| `--core` | Core packages only (`git curl jq tmux`), never `kitty`/`wl-clipboard`. |
| `--all` | Core + desktop packages, even without a detected display. |
| `--dry-run` | Print the package command instead of running it. |

## What's here

| Module | What it does |
|---|---|
| `deps/` | System packages for the other modules, via apt/dnf/pacman/zypper. Splits them into **core** (`git curl jq tmux`) and **desktop** (`kitty wl-clipboard`), and probes each command on `PATH` first — so a manually installed kitty in `~/.local/bin` is never shadowed by a package one. |
| `claude/` | Claude Code status line: 3-line bar with Nerd Font icons, git info, and usage bars (5h / 7d / 7d-fable / context). `install.sh` copies the script to `~/.claude/` and merges the `statusLine` block into `~/.claude/settings.json` (backup kept). |
| `kitty/` | kitty terminal config: JetBrainsMono Nerd Font, powerline tabs, translucent dark background, custom 16-color palette. `install.sh` copies it to `~/.config/kitty/kitty.conf` (backup kept). |
| `tmux/` | tmux config: mouse on, mouse-drag selection copies to the Wayland clipboard via `wl-copy`. `install.sh` copies it to `~/.tmux.conf` (backup kept). |
| `fonts/` | JetBrainsMono Nerd Font installers for Linux (`.sh`) and Windows (`.ps1`). The font must be installed on the machine that **renders** the terminal — your local desktop, not the server you SSH into. Then set the terminal font to "JetBrainsMono Nerd Font" (Windows Terminal: Settings > Profiles > Defaults > Appearance > Font face). |

## Notes

- Package installation needs `sudo` (or root). Nothing else in the repo does.
- Status line dependencies on the server: `bash`, `jq`, `curl`, `git`.
- The tmux copy bindings need `wl-copy` (`wl-clipboard`) and a Wayland session;
  on X11 swap it for `xclip -sel clip`.
- On a headless server, `./setup.sh` installs the core packages only, but still
  writes `kitty.conf` — harmless, just unused.
- The `7d-fable` usage bar reads the Claude.ai OAuth token from
  `~/.claude/.credentials.json` and queries an **undocumented** endpoint
  (`api.anthropic.com/api/oauth/usage`, cached 60s). It degrades silently
  if the endpoint changes or the machine uses API-key auth.
- Status line icons are Nerd Font glyphs; without the font they show as boxes.

## Planned

- oh-my-zsh config
- (add dotfiles/modules here as they accumulate)
