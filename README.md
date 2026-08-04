# dotfiles

Terminal setup built around tmux + Claude Code: sessions are linked to tmux
tabs, and tabs light up green when Claude wants you.

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh --dry     # preview
./install.sh           # symlink everything
exec zsh
```

Anything already at a destination is moved to `<file>.bak-<timestamp>`, never
overwritten. Re-running is safe. `./install.sh --unlink` reverses it.

### Dependencies

```sh
brew install tmux jq fzf yazi glow
```

`jq` is required (the Claude hooks parse JSON with it). `fzf` powers the
session picker. `yazi` and `glow` back the `y` and `g` aliases.

## What's here

| Path | Links to |
|---|---|
| `home/.zshrc` | `~/.zshrc` |
| `home/.tmux.conf` | `~/.tmux.conf` |
| `config/yazi/*.toml` | `~/.config/yazi/` |
| `config/cmux/cmux.json` | `~/.config/cmux/` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `ghostty/config` | macOS: `~/Library/Application Support/com.mitchellh.ghostty/config`<br>Linux: `~/.config/ghostty/config` |
| `bin/*` | `~/.local/bin/` |

## Commands

| Command | Does |
|---|---|
| `c` | Claude, pinning the tmux window name so the tab stops drifting |
| `lc` | List/resume Claude sessions belonging to **this tmux tab** |
| `lc -a` | Same, across every tab |
| `lcl` | Link a running session to this tab (`-p` picker, `-l` list) |
| `tc` | tmux workspace launcher (`tc 6`, `tc -r`, `tc -k`) |
| `y` | yazi, cd-ing to wherever you exit |
| `g` / `o` / `vw` | glow / open / json-viewer |

## How the Claude ↔ tmux linkage works

Four Claude Code hooks in `claude/settings.json`:

| Hook | Script | Effect |
|---|---|---|
| `SessionStart` | `claude-tag-session` | Records `session_id → tmux window` in `~/.claude/tmux-index.jsonl` |
| `UserPromptSubmit` | `claude-tmux-alert busy` | Tab turns purple ◐ — Claude is working |
| `Stop` | `claude-tmux-alert on` | Tab turns green ● — finished, your turn |
| `Notification` | `claude-tmux-alert on` | Tab turns green ● — needs permission |

### Tab colours

| State | Colour | Contrast on `#1a1b26` | Weight |
|---|---|---|---|
| idle | `#565f89` | 2.8:1 | normal |
| working ◐ | `#bb9af7` | 7.4:1 | normal |
| your turn ● | `#9ece6a` | 9.4:1 | **bold** |

Salience tracks required action: working never out-shouts the state that
actually needs you. Cyan (10.0:1) was rejected for inverting that hierarchy.

### Several sessions in one tab

State is stored per **pane** in `@claude_state`, and the tab colour is a
rollup of all its panes:

| Panes | Tab |
|---|---|
| any needs you | green ● |
| else any working | purple ◐ |
| else | dim |

Green wins deliberately. Storing state on the window instead lets concurrent
sessions clobber each other — a session starting work would erase another
session's "your turn" and the notification would be lost outright.

Each pane also labels its own state in its top border, so you can tell *which*
session in a tab wants you:

```
┌─ ● ready  hydroboat-recon-v2 ──────┐   green
├─ ◐ working  aai-api ───────────────┤   purple
├─ dev-workspace ────────────────────┤   dim
```

Green clears when you **focus the pane**, not when you visit the tab — so a
tab with three sessions stays green until you've seen each one that wants you.

Three tmux hooks are needed, because tmux reaches a pane by three routes:

| Hook | Route |
|---|---|
| `after-select-pane` | clicking inside a pane, `prefix`+arrow |
| `after-select-window` | `prefix`+*n*, next/previous-window |
| `session-window-changed` | **clicking a tab in the status bar** |

That last one matters: a status-bar click runs `switch-client -t =`, not
`select-window`, so hooking only `after-select-window` silently misses every
mouse user.

The border *line* colour cannot vary per pane — tmux accepts
`set-option -p pane-border-style` but discards it, and it never appears in
the pane option table. The border *format* is evaluated per pane, so
`@claude_state` works there. Costs one screen row in total, not one per pane.

Every hook resolves `$TMUX_PANE` to a window id, which is what ties a session
to a specific tab even when you're looking elsewhere. `~/.tmux.conf` renders
the green via `#{?@claude_alert,…}` and clears it with an
`after-select-window` hook.

The index is keyed on **both** window id and window name: the id is exact
while the tmux server lives, the name survives a restart.

### Machine-local state (not tracked)

`~/.claude/tmux-index.jsonl` is generated per machine and deliberately not in
git — window ids and paths don't transfer. It rebuilds itself as you work; use
`lcl` to backfill sessions that predate it.

## Colour scheme

Ghostty runs Terminal.app's Homebrew profile with the hue rotated green → red,
desaturated to coral (`#FF6B5C`). Pure red only reaches 5.3:1 contrast on
black and fringes badly; coral gets 7.5:1. ANSI blue is remapped for the same
reason — the stock `#0000B2` is **1.6:1**, effectively invisible. Yazi's
directory colour is overridden to teal for the same reason.

## Not tracked

Two files are deliberately excluded so this repo stays publishable:

| File | Why | Template |
|---|---|---|
| `~/.claude/CLAUDE.md` | Names clients and colleagues | `claude/CLAUDE.md.template` |
| `~/.zshrc.local` | Client paths, local proxies, absolute paths | `home/.zshrc.local.template` |

`.zshrc` sources `~/.zshrc.local` last if it exists, so machine-local settings
override anything tracked. Anything that hardcodes `/Users/<you>` or names a
client belongs there, not here.
