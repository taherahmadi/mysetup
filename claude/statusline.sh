#!/bin/bash
# Claude Code Status Line
input=$(cat)

# ── Path display ──
# tildify PATH [SEP] — replace a leading $HOME with "~".
# SEP is the separator PATH uses: "/" for real filesystem paths, "-" for
# Claude Code transcript slugs (which encode "/" as "-"). $HOME is read at
# runtime, so this works for whoever cloned the repo. Output always uses "/".
tildify() {
    local path="$1" sep="${2:-/}" home="${HOME:-}"
    if [ -z "$home" ]; then echo "$path"; return; fi
    [ "$sep" = "/" ] || home="${home//\//$sep}"
    if [ "$path" = "$home" ]; then
        echo "~"
    elif [ "${path#"$home$sep"}" != "$path" ]; then
        echo "~/${path#"$home$sep"}"
    else
        echo "$path"
    fi
}

# ── Extract all fields ──
# One jq pass instead of one per field. @sh quotes every value, so eval is
# safe even for directories with spaces or quotes in them.
eval "$(echo "$input" | jq -r '
    def q: @sh;
    "MODEL=\(.model.display_name // "?" | q)",
    "DIR=\(.workspace.current_dir // "" | q)",
    "TRANSCRIPT_PATH=\(.transcript_path // "" | q)",
    "COST=\(.cost.total_cost_usd // 0 | q)",
    "PCT=\(.context_window.used_percentage // 0 | floor | q)",
    "DURATION_MS=\(.cost.total_duration_ms // 0 | q)",
    "LINES_ADDED=\(.cost.total_lines_added // 0 | q)",
    "LINES_REMOVED=\(.cost.total_lines_removed // 0 | q)",
    "SESSION_NAME=\(.session_name // "" | q)",
    "WORKTREE_NAME=\(.worktree.name // "" | q)",
    "GIT_WORKTREE=\(.workspace.git_worktree // "" | q)",
    "AGENT_NAME=\(.agent.name // "" | q)",
    "VIM_MODE=\(.vim.mode // "" | q)",
    "TOTAL_IN=\(.context_window.total_input_tokens // 0 | q)",
    "TOTAL_OUT=\(.context_window.total_output_tokens // 0 | q)",
    "SESSION_ID=\(.session_id // "" | q)",
    "EXCEEDS_200K=\(.exceeds_200k_tokens // false | q)",
    # Rate limits (Claude.ai subscribers): "label|pct" per line
    "RATE_LIMITS=\([.rate_limits // {} | to_entries[]
        | select(.value.used_percentage != null)
        | "\(.key)|\(.value.used_percentage)"] | join("\n") | q)"
' 2>/dev/null)"

# Fallbacks so the bar still renders if the input JSON was unparseable.
: "${MODEL:=?}" "${PCT:=0}" "${COST:=0}" "${DURATION_MS:=0}" "${LINES_ADDED:=0}" \
  "${LINES_REMOVED:=0}" "${TOTAL_IN:=0}" "${TOTAL_OUT:=0}" "${EXCEEDS_200K:=false}"

# Original launch dir, recovered from the transcript path.
# Format: ~/.claude/projects/-home-<user>-Projects-emr-annotation/session.jsonl
PROJECT_SLUG=$(echo "$TRANSCRIPT_PATH" | sed 's|.*/projects/||; s|/.*||')
LAUNCH_DIR=$(tildify "$PROJECT_SLUG" "-")

# ── Colors ──
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
BG_RED='\033[41m'
GRAY='\033[90m'

# ── Nerd Font icons (generated via \u escapes so the file stays ASCII) ──
ICON_LAUNCH=$''   # rocket
ICON_DIR=$''      # open folder
ICON_WT=$''       # code fork
ICON_REPO=$''     # repo (octicons)
ICON_BRANCH=$''   # powerline branch

# ── Theme (user-picked mix: Tide model, Autumn session/repo/branch, Meadow dir, Coral bars) ──
THEME_MODEL='\033[1;38;5;37m'    # bold teal
THEME_SESSION='\033[38;5;209m'   # salmon
THEME_DIR='\033[38;5;150m'       # sage
THEME_REPO='\033[1;38;5;214m'    # bold orange
THEME_BRANCH='\033[38;5;70m'     # deep green
THEME_SEP='\033[38;5;101m'       # warm gray
THEME_LAUNCH='\033[38;5;246m'    # light gray (de-emphasized)

# ── Column alignment ──
# Width (in visible characters) to which the first field of each line is padded
# so that the ✾ dividers fall on the same column across all three lines.
FIELD_WIDTH=28

# visible_len STRING — returns the visible length of STRING after stripping ANSI codes
visible_len() {
    echo -n "$1" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | wc -m | tr -d ' '
}

# pad_right ANSI_STRING TARGET_WIDTH — appends spaces until visible width == TARGET_WIDTH
pad_right() {
    local s="$1" target="$2"
    local vlen
    vlen=$(visible_len "$s")
    local pad=$(( target - vlen ))
    if [ "$pad" -gt 0 ]; then
        printf -v SPACES "%${pad}s" ""
        echo -n "${s}${SPACES}"
    else
        echo -n "$s"
    fi
}

# pct_color PCT — echoes the gradient color code for a usage percentage
pct_color() {
    if [ "$1" -ge 90 ]; then echo "$RED"
    elif [ "$1" -ge 70 ]; then echo "$YELLOW"
    elif [ "$1" -ge 40 ]; then echo "$CYAN"
    else echo "$GREEN"
    fi
}

# make_bar PCT WIDTH — echoes a █/░ bar string
make_bar() {
    local pct=$1 width=$2 filled empty bar=""
    filled=$(( pct * width / 100 ))
    empty=$(( width - filled ))
    for _i in $(seq 1 $filled 2>/dev/null); do bar="${bar}█"; done
    for _i in $(seq 1 $empty 2>/dev/null); do bar="${bar}░"; done
    echo "$bar"
}

# pct_bgcolor PCT — pastel version of the green/cyan/yellow/red usage gradient
pct_bgcolor() {
    if [ "$1" -ge 90 ]; then echo '\033[48;5;210m'   # pastel red
    elif [ "$1" -ge 70 ]; then echo '\033[48;5;222m' # pastel yellow
    elif [ "$1" -ge 40 ]; then echo '\033[48;5;116m' # pastel cyan
    else echo '\033[48;5;151m'                       # pastel green
    fi
}

# inline_bar LABEL PCT — title and percent centered on the bar itself:
# filled fraction is a colored background, the rest is gray background
inline_bar() {
    local label="$1 $2%" width=14 text filled bg
    local pad_total=$(( width - ${#label} ))
    [ "$pad_total" -lt 0 ] && pad_total=0
    printf -v text '%*s%s%*s' "$(( pad_total / 2 ))" '' "$label" "$(( pad_total - pad_total / 2 ))" ''
    filled=$(( $2 * ${#text} / 100 ))
    bg=$(pct_bgcolor "$2")
    echo -n "${GRAY}[${RESET}${bg}\033[30m${text:0:filled}${RESET}\033[100m\033[30m${text:filled}${RESET}${GRAY}]${RESET}"
}

# ── Format tokens ──
format_tokens() {
    local tokens=$1
    if [ "$tokens" -ge 1000000 ]; then
        printf "%.1fM" "$(echo "scale=1; $tokens / 1000000" | bc 2>/dev/null || echo "?")"
    elif [ "$tokens" -ge 1000 ]; then
        printf "%.1fK" "$(echo "scale=1; $tokens / 1000" | bc 2>/dev/null || echo "?")"
    else
        echo "$tokens"
    fi
}

IN_FMT=$(format_tokens "$TOTAL_IN")
OUT_FMT=$(format_tokens "$TOTAL_OUT")

# ── Format duration ──
TOTAL_SECS=$((DURATION_MS / 1000))
TOTAL_MINS=$((TOTAL_SECS / 60))
TOTAL_HRS=$((TOTAL_MINS / 60))
REMAINING_MINS=$((TOTAL_MINS % 60))
REMAINING_SECS=$((TOTAL_SECS % 60))

if [ "$TOTAL_HRS" -gt 0 ]; then
    DURATION_FMT="${TOTAL_HRS}h${REMAINING_MINS}m"
elif [ "$TOTAL_MINS" -gt 0 ]; then
    DURATION_FMT="${TOTAL_MINS}m${REMAINING_SECS}s"
else
    DURATION_FMT="${TOTAL_SECS}s"
fi

# ── Format cost ──
COST_FMT=$(printf '$%.2f' "$COST")

# ── Git info (cached for performance) ──
CACHE_FILE="/tmp/claude-statusline-git-${SESSION_ID}"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

GIT_REPO="" BRANCH="" STAGED=0 MODIFIED=0 UNTRACKED=0 AHEAD=0 BEHIND=0 STASHES=0
if cache_is_stale; then
    if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
        GIT_REPO=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
        BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
        STAGED=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        UNTRACKED=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        AHEAD=$(git -C "$DIR" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
        BEHIND=$(git -C "$DIR" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
        STASHES=$(git -C "$DIR" stash list 2>/dev/null | wc -l | tr -d ' ')
        echo "${GIT_REPO}|${BRANCH}|${STAGED}|${MODIFIED}|${UNTRACKED}|${AHEAD}|${BEHIND}|${STASHES}" > "$CACHE_FILE"
    else
        echo "|||||||" > "$CACHE_FILE"
    fi
fi

IFS='|' read -r GIT_REPO BRANCH STAGED MODIFIED UNTRACKED AHEAD BEHIND STASHES < "$CACHE_FILE"

# ── Model-scoped weekly limits (undocumented OAuth usage endpoint, cached) ──
# The statusline stdin JSON only carries five_hour/seven_day; the per-model
# weekly bar shown by /usage comes from api.anthropic.com/api/oauth/usage.
# Token is read locally and sent only to api.anthropic.com.
USAGE_CACHE="/tmp/claude-statusline-usage-${USER:-$(id -un)}.json"
USAGE_TTL=60

usage_cache_stale() {
    [ ! -f "$USAGE_CACHE" ] || \
    [ $(($(date +%s) - $(stat -c %Y "$USAGE_CACHE" 2>/dev/null || stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0))) -gt $USAGE_TTL ]
}

if usage_cache_stale; then
    OAUTH_TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
    if [ -n "$OAUTH_TOKEN" ]; then
        USAGE_RESP=$(curl -s --max-time 2 "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $OAUTH_TOKEN" \
            -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
        if echo "$USAGE_RESP" | jq -e '.limits' >/dev/null 2>&1; then
            echo "$USAGE_RESP" > "$USAGE_CACHE"
        else
            # Endpoint failed/changed: back off for one TTL, keep stale data if any
            touch "$USAGE_CACHE" 2>/dev/null
        fi
    fi
fi

SCOPED_LIMITS=""
if [ -s "$USAGE_CACHE" ]; then
    SCOPED_LIMITS=$(jq -r '.limits[]? |
        select(.kind == "weekly_scoped" and .scope.model.display_name != null) |
        "7d-\(.scope.model.display_name | ascii_downcase)|\(.percent)"' "$USAGE_CACHE" 2>/dev/null)
fi

# ── LINE 1: Model  session-id  agent  vim-mode  launch-dir ──
LINE1=""

# Model badge — pad to FIELD_WIDTH before the first ✾
LINE1="$(pad_right "${THEME_MODEL}${MODEL}${RESET}" "$FIELD_WIDTH")"

# Session name with ID fallback
if [ -n "$SESSION_NAME" ]; then
    LINE1="${LINE1}  ${THEME_SEP}✾${RESET}  ${THEME_SESSION}#${SESSION_NAME}${RESET}"
elif [ -n "$SESSION_ID" ]; then
    LINE1="${LINE1}  ${THEME_SEP}✾${RESET}  ${DIM}${THEME_SESSION}#${SESSION_ID}${RESET}"
fi

# Agent name
if [ -n "$AGENT_NAME" ]; then
    LINE1="${LINE1}  ${THEME_SEP}✾${RESET}  ${MAGENTA}@${AGENT_NAME}${RESET}"
fi

# Vim mode
if [ -n "$VIM_MODE" ]; then
    if [ "$VIM_MODE" = "NORMAL" ]; then
        LINE1="${LINE1}  ${THEME_SEP}✾${RESET}  ${BOLD}${BLUE}[N]${RESET}"
    elif [ "$VIM_MODE" = "VISUAL" ] || [ "$VIM_MODE" = "VISUAL LINE" ]; then
        LINE1="${LINE1}  ${THEME_SEP}✾${RESET}  ${BOLD}${MAGENTA}[V]${RESET}"
    else
        LINE1="${LINE1}  ${THEME_SEP}✾${RESET}  ${BOLD}${GREEN}[I]${RESET}"
    fi
fi

# Launch dir (the directory the session was initiated from)
if [ -n "$LAUNCH_DIR" ]; then
    LINE1="${LINE1}  ${THEME_LAUNCH}${ICON_LAUNCH} ${LAUNCH_DIR}${RESET}"
fi

# ── LINE 2: CWD  git-repo  branch  ahead/behind  staged/modified/untracked ──
LINE2=""

# Full current working directory ($HOME shortened to ~)
DIR_DISPLAY=$(tildify "$DIR")
LINE2="${THEME_DIR}${ICON_DIR} ${DIR_DISPLAY}${RESET}"

# Worktree annotation (if applicable)
if [ -n "$WORKTREE_NAME" ]; then
    LINE2="${LINE2}  ${YELLOW}[${ICON_WT} ${WORKTREE_NAME}]${RESET}"
elif [ -n "$GIT_WORKTREE" ]; then
    LINE2="${LINE2}  ${YELLOW}[${ICON_WT} ${GIT_WORKTREE}]${RESET}"
fi

# Pad the leading dir+worktree block to FIELD_WIDTH before the first ✾
LINE2="$(pad_right "$LINE2" "$FIELD_WIDTH")"

# Git repo name
if [ -n "$GIT_REPO" ]; then
    LINE2="${LINE2}  ${THEME_REPO}${ICON_REPO} ${GIT_REPO}${RESET}"
fi

# Git branch
if [ -n "$BRANCH" ]; then
    LINE2="${LINE2}  ${THEME_BRANCH}${ICON_BRANCH} ${BRANCH}${RESET}"

    # Ahead/behind remote
    if [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
        LINE2="${LINE2}  ${YELLOW}↑${AHEAD}↓${BEHIND}${RESET}"
    elif [ "$AHEAD" -gt 0 ]; then
        LINE2="${LINE2}  ${GREEN}↑${AHEAD}${RESET}"
    elif [ "$BEHIND" -gt 0 ]; then
        LINE2="${LINE2}  ${RED}↓${BEHIND}${RESET}"
    fi

    # Staged / modified / untracked counts
    CHANGES=""
    [ "$STAGED" -gt 0 ]    && CHANGES="${CHANGES}${GREEN}${STAGED} staged${RESET}  "
    [ "$MODIFIED" -gt 0 ]  && CHANGES="${CHANGES}${YELLOW}${MODIFIED} modified${RESET}  "
    [ "$UNTRACKED" -gt 0 ] && CHANGES="${CHANGES}${RED}${UNTRACKED} untracked${RESET}  "
    [ -n "$CHANGES" ] && LINE2="${LINE2}  ${THEME_SEP}✾${RESET}  ${CHANGES}"

    # Stashes
    [ "$STASHES" -gt 0 ] && LINE2="${LINE2}${DIM}${GRAY}stash:${STASHES}${RESET}  "
fi

# ── LINE 3: rate-limit bars  context  in/out tokens  cost  duration  lines ──
LINE3=""

# Exceeds 200K warning
if [ "$EXCEEDS_200K" = "true" ]; then
    LINE3="${BG_RED}${WHITE}${BOLD} >200K ${RESET}"
fi

# Rate limit usage bars first (Claude.ai subscribers only), titles inside the bars
ALL_LIMITS=$(printf '%s\n%s' "$RATE_LIMITS" "$SCOPED_LIMITS" | grep -v '^$')
if [ -n "$ALL_LIMITS" ]; then
    while IFS='|' read -r RL_KEY RL_PCT; do
        [ -z "$RL_KEY" ] && continue
        RL_PCT=$(printf '%.0f' "$RL_PCT")
        case "$RL_KEY" in
            five_hour)  RL_LABEL="5h" ;;
            seven_day)  RL_LABEL="7d" ;;
            *)          RL_LABEL=$(echo "$RL_KEY" | tr '_' '-') ;;
        esac
        LINE3="${LINE3}$(inline_bar "$RL_LABEL" "$RL_PCT") "
    done <<< "$ALL_LIMITS"
fi

# Context window bar, same style as the rate-limit bars
LINE3="${LINE3}$(inline_bar "ctx" "$PCT")"

# Pad the leading pct block to FIELD_WIDTH before the first ✾
LINE3="$(pad_right "$LINE3" "$FIELD_WIDTH")"

# Input / output tokens
LINE3="${LINE3}  ${THEME_SEP}✾${RESET}  ${DIM}in:${RESET}${IN_FMT} ${DIM}out:${RESET}${OUT_FMT}"

# Cost
LINE3="${LINE3}  ${THEME_SEP}✾${RESET}  ${YELLOW}${COST_FMT}${RESET}"

# Duration
LINE3="${LINE3}  ${THEME_SEP}✾${RESET}  ${DIM}${DURATION_FMT}${RESET}"

# Lines changed
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
    LINE3="${LINE3}  ${THEME_SEP}✾${RESET}  ${GREEN}+${LINES_ADDED}${RESET}${RED}-${LINES_REMOVED}${RESET}"
fi


# ── Output ──
printf '%b\n' "$LINE1"
printf '%b\n' "$LINE2"
printf '%b\n' "$LINE3"
