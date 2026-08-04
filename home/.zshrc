
. "$HOME/.local/bin/env"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform
# Cursor CLI
export PATH="/Applications/Cursor.app/Contents/Resources/app/bin:$PATH"

# Open Microsoft Visual Studio Code (the Cursor PATH above hijacks `code`)
alias code='"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"'

alias cx='codex --yolo'

# ─── Claude sessions linked to tmux tabs ─────────────────────
# `c`  launch Claude, pinning the tmux window name so the tab stays stable
# `lc` list/resume Claude sessions belonging to THIS tab  (lc -a = all tabs)
#
# The tab<->session link is recorded by the SessionStart hook
# ~/.local/bin/claude-tag-session into ~/.claude/tmux-index.jsonl.

c() {
  # Only pin the name if tmux is still auto-renaming this window. If you
  # already named the tab yourself, automatic-rename is off and we leave
  # your name completely alone.
  if [ -n "$TMUX" ] && \
     [ "$(tmux show-window-options -v automatic-rename 2>/dev/null)" != "off" ]; then
    local root label
    root="$(git rev-parse --show-toplevel 2>/dev/null)"
    label="$(basename "${root:-$PWD}")"
    tmux set-window-option automatic-rename off >/dev/null 2>&1
    tmux rename-window "$label" >/dev/null 2>&1
  fi
  command claude --dangerously-skip-permissions "$@"
}

# Backfill: link sessions that predate the hook to the current tab.
#   lcl          link live Claude sessions running in this tab
#   lcl -p       pick any past session and link it here
#   lcl -l       show what's linked to this tab
lcl() {
  local a=()
  case "${1:-}" in
    -p|--pick) a=(--pick) ;;
    -l|--list) a=(--list) ;;
    *)         a=("$@") ;;
  esac
  command claude-tab-link "${a[@]}"
}

lc() {
  local arg=""
  case "${1:-}" in -a|--all) arg="--all" ;; esac

  local out
  out="$(command claude-tab-pick $arg)" || return
  [ -n "$out" ] || return

  local dir="${out%%$'\t'*}" sid="${out##*$'\t'}"
  [ -d "$dir" ] || { print -u2 "lc: directory gone: $dir"; return 1; }

  builtin cd -- "$dir" || return
  command claude --dangerously-skip-permissions --resume "$sid"
}

# tmux-claude shortcut
alias tc="tmux-claude"

# yazi file browser — cd to last directory on exit
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# markdown renderer
alias g="glow"

# open in Finder
alias o="open"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# ─── Machine-local config ────────────────────────────────────
# Client paths, personal proxy setup, and anything hardcoding an absolute
# path lives in ~/.zshrc.local, which is deliberately NOT tracked in the
# dotfiles repo. Keep this line last so local settings win.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
