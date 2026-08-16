---
name: niri-config
description: Reference for niri's config.kdl syntax and its JSON IPC (`niri msg`) as used in this repo's niri/ config and shell/services/Niri.qml. Load before editing any niri/*.kdl file, writing/reviewing `niri msg`/`niri msg action` invocations, or touching Niri.qml's event-stream parsing.
---

# niri config + IPC reference (this repo)

Pinned to **niri 26.04** (`niri --version`). Niri ships frequent releases and its own docs note the IPC crate "follows niri's version numbering... new fields/variants are added" — i.e. it is *not* API-stable across versions the way a 1.0 library would be. If the installed version has moved on from 26.04, don't assume anything below still matches — re-check live (see bottom).

**The project moved GitHub orgs**: it's `niri-wm/niri` now, not `YaLTeR/niri` (old org URLs redirect but some docs links found in the wild — including a comment in this repo's own `shell/services/Niri.qml` — still point at the dead `yalter.github.io` domain, which 404s). Use the `niri-wm.github.io`/`github.com/niri-wm/niri` URLs below.

## Config file layout in this repo

`niri/` is symlinked to `~/.config/niri` by `install.sh shell` (see `AGENTS.md`). Structure:

```
niri/config.kdl      just: include "main.kdl"
niri/main.kdl        includes the four files below + top-level settings (environment{}, screenshot-path, debug{})
niri/keybinds.kdl     binds {} block — all keybindings
niri/peripherals.kdl  input {} block (keyboard/touchpad/mouse) — also includes keybinds.kdl itself
niri/windows.kdl      layer-rule{}, window-rule{}, overview{}, hotkey-overlay{}, cursor{}, etc.
niri/outputs.kdl      output "<name>" {} blocks, one per monitor
```

Config is **live-reloaded** — saving any included file applies changes immediately, no niri restart needed. Validate without applying: `niri validate` (run from inside a niri session, or point `--config`/`-c` at a specific file).

## KDL syntax basics

[KDL](https://kdl.dev) is a block-based config language, not YAML/TOML/JSON. Patterns actually used in this repo's `niri/*.kdl`:

```kdl
// line comment
/* block comment */

key value;                          // a plain setting, e.g. `screenshot-path "..."`
key value=arg;                      // a "prop" — named argument, e.g. `variable-refresh-rate on-demand=true`
flag-only-setting                   // presence alone means "on" (no value) — e.g. `numlock`, `tap`
block-name {                        // nested block — most config sections are these
    nested-key value
}
Mod+Shift+Slash { show-hotkey-overlay; }         // keybind: modifiers+key, then an action block
Mod+T hotkey-overlay-title="..." { spawn "alacritty"; }   // a bind can carry its own props before the {}
include "other-file.kdl"            // relative to the including file's directory
```

Commenting out a single line (rather than the whole block) is the usual way to try a setting — see `outputs.kdl`'s commented `// mode "1920x1080@120.030"` etc.

## `spawn` vs `spawn-sh` in keybinds

`spawn "cmd" "arg1" "arg2"` — argv array, **no shell involved**. This is what almost every bind in `keybinds.kdl` uses (`spawn "qs" "ipc" "call" "lockscreen" "lock"`). Prefer this — matches this repo's general "no unnecessary shell interpolation" convention (see `AGENTS.md`'s `Quickshell.Io` guidance on the same principle).

`spawn-sh "shell command string"` exists for when you actually need shell features (pipes, `&&`, globbing) — not currently used anywhere in this repo's keybinds; reach for `spawn` first.

## `niri msg` — the CLI entry point to niri's IPC

Two shapes, both used in this repo:

**One-shot query** (`shell/services/Niri.qml`'s `workspacesProc`/`activeWindowProc` pattern — see the `quickshell-api` skill for the `Process`/`StdioCollector` QML side of this):
```bash
niri msg --json workspaces
niri msg --json focused-window
niri msg --json outputs
niri msg --json windows
niri msg --json layers          # useful for finding a layer-shell surface's namespace, e.g. windows.kdl's layer-rule match
```

**Long-running event stream** (never exits — `shell/services/Niri.qml` parses it incrementally via `SplitParser`, not `StdioCollector`):
```bash
niri msg --json event-stream
```
Per niri's own docs: the stream first sends the complete current state, then incremental updates — don't assume you need to separately query current state before subscribing.

**Imperative actions** (what niri keybinds' `{ ... }` blocks and manual `niri msg action ...` calls both ultimately invoke):
```bash
niri msg action toggle-overview
niri msg action close-window
niri msg action do-something        # generic escape hatch some binds reference in comments
```
There are well over a hundred actions (window/column/workspace focus-and-move variants, screenshot, monitor power, etc.) — too many to enumerate here reliably. Ground truth: `niri msg action --help` lists them all with one-line descriptions; `niri msg action <action> --help` gives that action's exact argument shape. Always check there rather than guessing an action name or its args.

Full request/response/event type reference (for anything beyond simple CLI usage, e.g. writing a raw socket client): https://niri-wm.github.io/niri/niri_ipc/

## Backwards-compatibility note (from niri's own docs)

- Existing JSON fields persist across versions; new ones may be *added* — code parsing `niri msg --json` output (like `Niri.qml`) should tolerate unknown extra fields rather than validating an exact schema.
- The **human-readable** (non-`--json`) output is explicitly *not* stable — never parse it, only `--json` output.
- `niri validate` catches config syntax/semantic errors before they'd otherwise surface as a live-reload failure.

## When this runs out

For anything not covered above — a new config section, an action whose exact argument shape matters, or if `niri --version` no longer prints `26.04` — don't guess:

- Config reference: https://niri-wm.github.io/niri/Configuration%3A-Introduction.html (also browsable as the GitHub wiki: https://github.com/niri-wm/niri/wiki/Configuration:-Overview) and the canonical fully-commented example at https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl — the single most reliable source for "what are all the valid keys in section X," since it ships embedded in the niri binary itself and is what niri writes out for a fresh config.
- IPC reference: https://niri-wm.github.io/niri/niri_ipc/
- Locally: `niri msg --help`, `niri msg action --help`, `niri validate` are always in sync with whatever version is actually installed, more so than any doc snapshot.

Update this file with what you learn if it's something this repo will keep using.
