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
| `codex/hooks.json` | `~/.codex/hooks.json` |
| `ghostty/config` | macOS: `~/Library/Application Support/com.mitchellh.ghostty/config`<br>Linux: `~/.config/ghostty/config` |
| `share/tmux-cheatsheet.txt` | `~/.local/share/tmux-cheatsheet.txt` |
| `bin/*` | `~/.local/bin/` |

## Commands

| Command | Does |
|---|---|
| `c` | Claude, pinning the tmux window name so the tab stops drifting |
| `lc` | List/resume Claude sessions belonging to **this tmux tab** |
| `lc -a` | Same, across every tab |
| `lcl` | Link a running session to this tab (`-p` picker, `-l` list, `-u` unlink) |
| `tc` | tmux workspace launcher (`tc 6`, `tc -r`, `tc -k`) |
| `cx` | codex `--yolo`, pinning the tab name the same way `c` does |
| `lcx` | List/resume **codex** sessions belonging to this tab (`-a` = all tabs) |
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

### Codex, same wiring

Codex 0.149+ implements Claude Code's hook contract - identical event names,
identical JSON payload on stdin, and it exports `TMUX_PANE` to the hook
process. So `codex/hooks.json` points at the *same* scripts and codex gets the
same purple/green tab behaviour for free:

| Hook | Script | Effect |
|---|---|---|
| `SessionStart` | `codex-tag-session` | Records `session_id → tmux window` in `~/.codex/tmux-index.jsonl` |
| `UserPromptSubmit` | `claude-tmux-alert busy --json` | Tab turns purple ◐ |
| `Stop` | `claude-tmux-alert on --json` | Tab turns green ● |

Three things differ from Claude and are worth knowing:

* **Separate index.** Codex sessions go in `~/.codex/tmux-index.jsonl`, not
  Claude's. One shared index would let `lc` hand a codex id to
  `claude --resume`, which cannot resume it.
* **`--json`.** Codex rejects an empty response on `SessionStart`/`Stop`
  where Claude accepts one, so those commands pass `--json` and the scripts
  print `{}`.
* **Resume fires no hook.** `codex resume` does not fire `SessionStart`, so
  `lcx` re-tags the session itself via `codex-tab-relink` before resuming.
  Claude gets this for free from its own hook.

Codex asks you to trust hooks the first time it sees them, and again after
any edit to `hooks.json`; answer *Trust all and continue*. The hash lands in
`~/.codex/config.toml` under `[hooks.state]`.

`hooks.json` must be strict JSON with no extra keys - a `_comment` key at the
top level makes codex discard the whole file *silently*, with no error and no
hooks.

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
rollup of all its panes. Both agents write the same pane option, so a tab
holding one Claude and one codex pane rolls up correctly with no extra work:

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

### Unlinking

`lcl -u` opens a picker of what's linked to this tab (`TAB` marks several), or
takes session ids directly. The index is append-only, so an unlink is a
tombstone record rather than a rewrite — that keeps concurrent Claude sessions
appending without locking. Resuming the session in a tab re-tags it, which
re-links it; the tombstone is not permanent.

### Machine-local state (not tracked)

`~/.claude/tmux-index.jsonl` is generated per machine and deliberately not in
git — window ids and paths don't transfer. It rebuilds itself as you work; use
`lcl` to backfill sessions that predate it.

## Copy mode

`mode-keys vi`, so scrollback navigation is vim-shaped: `/` and `?` to search
with `n`/`N`, `g`/`G` for top/bottom, `Ctrl+u`/`Ctrl+d` half page, `w`/`b`/`e`
word motion, `f<char>` jump, `:<n>` goto-line, `H`/`M`/`L` screen position.
The last five have no equivalent in tmux's emacs table.

`v` starts a selection and `y` copies to the macOS clipboard — tmux's defaults
put `v` on rectangle-toggle and selection on `Space`, which no vim user
expects. Rectangle mode stays on `Ctrl+v`.

Mouse drag selects *and* copies via `pbcopy`, bound in both the vi and emacs
tables so it is unaffected by `mode-keys`.

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
