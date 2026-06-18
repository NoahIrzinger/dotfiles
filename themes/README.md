# themes

Swappable color themes for nvim + tmux, plus optional custom tmux status bars.

A theme is a palette. Both nvim and tmux render through Catppuccin, so switching a
theme just swaps the 26 palette colors. A theme may *also* ship a custom tmux status
bar (e.g. a multi-row custom header).

## Files

| File | Role |
|------|------|
| `<name>.theme` | the palette: `flavour=` + 26 `slot=hex` lines (no `#`) |
| `<name>.tmux`  | *optional* custom tmux status bar for that theme |
| `theme`        | the CLI (set / list / next / prev / reset / preview) |
| `active`       | the currently active theme name |
| `_preview.py`  | renders a status bar to a PNG (used by `theme preview`) |

Generated (not edited by hand), under `~/.config/tmux/`:

| File | Role |
|------|------|
| `theme.conf`            | `@thm_*` palette vars, written by `theme set` |
| `theme-style.conf`      | copy of the active theme's `<name>.tmux` (empty if none) |
| `.status-default.conf`  | cached pristine tmux `status-format` defaults (auto) |

## Commands

```
theme list            list themes (* = active)
theme set <name>      activate <name> (regenerates palette + reloads tmux/nvim/terminal, updates pi)
theme terminal [name] apply only terminal emulator foreground/background colors
theme next / prev     rotate alphabetically
theme try <name>      experiment: snapshot the current theme, apply <name> live
theme back            roll back to the theme before the last `try`
theme refresh         fast re-apply of the active header after editing its .tmux
theme reset           restore the default single-row bar (undo a stuck custom header)
theme preview [name]  render the theme's bar to a PNG and open it
```

## Terminal emulator colors

`theme set` also emits OSC 10/11/12 escape sequences for the current terminal
window/tab, so supported terminal emulators follow the same palette. This also
works from WSL when the host terminal supports those OSC color controls (for
example current Windows Terminal). Inside tmux, passthrough is enabled by this
repo's `tmux.conf`.

Use `theme terminal [name]` to re-apply only the terminal colors without changing
the active theme.

## Pi coding-agent theme

Custom pi themes live in `pi/.pi/agent/themes/` and are exposed at
`~/.pi/agent/themes` via symlink. `theme set light` writes
`"theme": "dotfiles-light"` to `~/.pi/agent/settings.json`; other themes map to
`dotfiles-dark`. Restart pi or run `/reload` in an existing session if the theme
does not update immediately.

## Experiment loop (live, with rollback)

Designed to be cheap and reversible while iterating on a bar in your real tmux:

```
theme try test        # snapshot whatever you're on, apply `test` live
                      #   (edit themes/test.tmux ...)
theme refresh         # re-apply the edited header in ~25ms (no full reload)
theme back            # roll back to what you had before `try`
```

`test` is the scratch theme reserved for this (a `test.theme` palette canvas; add a
`test.tmux` to design a header). `try` records the previous theme in
`~/.config/tmux/.theme-previous`; `back` re-applies it. Re-running `theme try test`
after edits does not lose the rollback target.

Safety: every apply runs `reset_status` first and sources the style with `-q`, so a
broken `.tmux` degrades to the default bar rather than a wedged one. Worst case,
`theme reset` always restores the default single-row bar. `theme preview test` lets
you see a change as a PNG *without* touching your session at all.

## How a theme renders in tmux

`tmux.conf` does, in order:

1. sources `theme.conf` (the `@thm_*` palette) before Catppuccin, so our colors win.
2. runs Catppuccin + the custom modules (cpu, ram, ip, kube, clock) -> the default
   single-row bar.
3. `run '.../tpm/tpm'` (must stay last among the synchronous lines).
4. **deferred**: `run-shell 'tmux source-file -q theme-style.conf'`.

Step 4 is deferred (a `run-shell` queued after tpm) on purpose. Catppuccin sets
`window-status-format` from its *own* async `run` job, and tpm re-sources Catppuccin
as another async job. A plain synchronous `source-file` of our style would run during
config parse, then get clobbered when those async jobs fire. Queuing it last makes a
custom header the final word. For a plain theme, `theme-style.conf` is empty, so step
4 is a no-op and the default Catppuccin bar stays.

## The swap gotcha (and the fix)

A custom header writes the multi-row `status-format[0..N]` array onto the live tmux
**server**, not just into a file. tmux options are server state, so they persist
across a config reload. If you then switch to a plain theme, nothing in its (empty)
style file clears those rows, so the old header's amber bars stay on screen and the
bar looks broken. `set -gu status-format[0]` does *not* help: once the option has
been set, unsetting it leaves it empty (a blank bar) instead of rebuilding tmux's
built-in default.

Fix: on every switch, `theme` runs `reset_status` *before* re-sourcing `tmux.conf`:

- `gen_status_default` captures tmux's real built-in `status-format` defaults once
  (by reading them from a throwaway `tmux -L … -f /dev/null` server) into
  `~/.config/tmux/.status-default.conf`.
- `reset_status` sources that file onto the live server: `status on`, default
  `status-format[0]`/`[1]`, and `status-format[2..4]` unset.

So the baseline is always restored first; then the active theme's style (if any)
layers its header back on. Switching is clean in both directions.

`theme reset` exposes this manually. If a bar ever looks wrong, run it.

## Designing a custom header

tmux's status bar is a grid of character cells. You get: text, Nerd Font / powerline
glyphs (pill caps `` ``, icons), and per-cell fg/bg colors. You can stack up to 5
rows (`set -g status 2..5`) and hand-author each row via `status-format[0..N]`. Row
index 0 is the topmost line; the highest index sits nearest the panes (with
`status-position top`).

You do **not** get vector shapes. No SVG, no images, no true curves or elbows. tmux
cannot render SVG, and its status line cannot host terminal image protocols (sixel /
kitty / iTerm imgcat work inside a pane, not in the bar). "Shape" caps out at
stadium pills (half-circle caps) and blocky pseudo-elbows built from solid color
runs. If you want real vector shapes, that's a different program (a desktop bar like
eww/ágs on Linux, or SwiftBar/Übersicht on macOS), not tmux.

Two rules that bit us, worth knowing:

- **Modules call scripts via `#()`, and tmux runs `#()` with an empty `PATH`.** So
  `cpu_percentage.sh` (needs `iostat`/`sysctl` in `/usr/sbin`) and `primary_ip.sh`
  (needs `route` in `/sbin`) come back blank unless you prefix the call:
  `#(PATH=/usr/sbin:/sbin:/usr/bin:/bin:/opt/homebrew/bin …/script.sh)`.
- **Inside the `#{W:noncurrent,current}` window loop, the comma is the argument
  separator.** So you cannot use `#[fg=x,bg=y]` (its comma splits the loop). Write
  styles comma-free: `#[fg=x]#[bg=y]`.

### Iterate with `theme preview`

The hard part of designing a bar is that `capture-pane` doesn't capture the status
line, so you can't see your work without applying it live. `theme preview <name>`
solves that: it spins a throwaway tmux with the theme's palette + `.tmux`, samples a
few windows, replays the rendered cells through a terminal emulator, and draws them
to a PNG (with your Nerd Font, so caps and icons show). Edit `<name>.tmux`, run
`theme preview <name>`, look at the image. No need to touch your real session.

Needs: `python3`, and `pip3 install pyte pillow`, plus a Nerd Font in
`~/Library/Fonts`.

`lcars.tmux` is the worked example: a 3-row elbow header (amber left bar + top arm,
stadium pills for session / windows / modules).
