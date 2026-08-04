#!/usr/bin/env bash
# Symlink this repo's files into place.
#
#   ./install.sh          link everything (backs up anything in the way)
#   ./install.sh --dry    show what would happen, change nothing
#   ./install.sh --unlink remove symlinks that point into this repo
#
# Existing real files are moved aside to <path>.bak-<timestamp> rather than
# deleted. Re-running is safe: correct links are left alone.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" && REPO="$PWD"

DRY=0; UNLINK=0
for a in "$@"; do
  case "$a" in
    --dry|-n)  DRY=1 ;;
    --unlink)  UNLINK=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 1 ;;
  esac
done

# Ghostty's config path differs by platform; everything else is XDG-ish.
case "$(uname -s)" in
  Darwin) GHOSTTY="$HOME/Library/Application Support/com.mitchellh.ghostty/config" ;;
  *)      GHOSTTY="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" ;;
esac

# repo-relative path  ->  destination
MANIFEST=(
  "home/.zshrc|$HOME/.zshrc"
  "home/.tmux.conf|$HOME/.tmux.conf"
  "config/yazi/yazi.toml|$HOME/.config/yazi/yazi.toml"
  "config/yazi/keymap.toml|$HOME/.config/yazi/keymap.toml"
  "config/yazi/theme.toml|$HOME/.config/yazi/theme.toml"
  "config/cmux/cmux.json|$HOME/.config/cmux/cmux.json"
  "claude/settings.json|$HOME/.claude/settings.json"
  "ghostty/config|$GHOSTTY"
  "bin/claude-tag-session|$HOME/.local/bin/claude-tag-session"
  "bin/claude-tab-pick|$HOME/.local/bin/claude-tab-pick"
  "bin/claude-tab-link|$HOME/.local/bin/claude-tab-link"
  "bin/claude-tmux-alert|$HOME/.local/bin/claude-tmux-alert"
  "bin/tmux-claude|$HOME/.local/bin/tmux-claude"
)

stamp="$(date +%s)"
linked=0; skipped=0; backed=0; removed=0

for entry in "${MANIFEST[@]}"; do
  src="$REPO/${entry%%|*}"
  dst="${entry##*|}"
  short="${dst/#$HOME/~}"

  if [ "$UNLINK" = 1 ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      [ "$DRY" = 1 ] && echo "  would unlink  $short" || { rm "$dst"; echo "  unlinked  $short"; }
      removed=$((removed+1))
    fi
    continue
  fi

  [ -e "$src" ] || { echo "  ⚠ missing in repo: ${entry%%|*}"; continue; }

  # already correct?
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skipped=$((skipped+1)); continue
  fi

  if [ "$DRY" = 1 ]; then
    if [ -e "$dst" ] || [ -L "$dst" ]; then echo "  would BACK UP + link  $short"
    else echo "  would link            $short"; fi
    linked=$((linked+1)); continue
  fi

  mkdir -p "$(dirname "$dst")"
  # Anything real in the way gets preserved, never clobbered.
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-$stamp"
    echo "  backed up  $short -> $(basename "$dst").bak-$stamp"
    backed=$((backed+1))
  fi
  ln -s "$src" "$dst"
  echo "  ✓ linked   $short"
  linked=$((linked+1))
done

[ "$UNLINK" = 1 ] && { echo; echo "unlinked $removed"; exit 0; }

chmod +x "$REPO"/bin/* 2>/dev/null

echo
if [ "$DRY" = 1 ]; then
  echo "dry run: $linked would change, $skipped already correct"
else
  echo "linked $linked · already correct $skipped · backed up $backed"
  echo
  echo "next:"
  echo "  exec zsh                       reload shell (aliases c, lc, lcl, y, tc)"
  echo "  tmux source-file ~/.tmux.conf  reload tmux"
  echo "  brew install jq fzf yazi glow tmux   if starting on a fresh machine"
fi
