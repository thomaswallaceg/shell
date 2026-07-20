# quickshell (niri)

Personal [Quickshell](https://quickshell.outfoxxed.me/) desktop shell for [niri](https://github.com/YaLTeR/niri): status bar, launcher panel, notifications, and OSD.

## What's included

| Piece | Description |
|-------|-------------|
| **Bar** | Top bar with CPU, temperature, niri workspaces, now playing, window title, system tray, volume, brightness, network, bluetooth, battery, and clock |
| **Panel** | App launcher with calculator (`2+2`), run mode (`> command`), file search (`? query` or inline), and a theme browser |
| **Notifications** | Notification popups |
| **OSD** | Brief volume / brightness feedback |
| **Themes** | Large palette set with live preview and persistence |
| **Greeter** | Optional standalone login screen for [greetd](https://github.com/kalyverse/greetd) (`greeter/`) — see below |

Bar widgets can open TUI tools in a floating terminal (alacritty by default). The bar auto-hides on a single monitor (hover or `qs ipc call bar peek`) and stays on the smallest screen when several are connected.

## Running

The main config lives in `shell/` (not at the repo root — see [Layout](#layout)), so it's a *named* Quickshell config. From `~/.config/quickshell` (or any checkout, via `-p`):

```bash
qs -c shell
# or: qs -p /path/to/this/repo/shell
```

If this repo is checked out at `~/.config/quickshell`, niri's config sets `QS_CONFIG_NAME "shell"` (see `niri/main.kdl`), so plain `qs` / `quickshell` — and `spawn-at-startup "quickshell"`, `qs ipc call ...` — default to `shell` without needing `-c` every time.

Config-relative assets use `Quickshell.shellPath(...)`. The active theme id is stored under Quickshell's per-shell state directory, so the checkout does not need to live in `~/.config/quickshell`.

Useful IPC (examples):

```bash
qs ipc call launcher toggle
qs ipc call theme toggle
qs ipc call bar toggle
qs ipc call bar peek
```

## Dependencies

### Required

- [Quickshell](https://quickshell.outfoxxed.me/) (Qt 6)
- [niri](https://github.com/YaLTeR/niri)
- A [Nerd Font](https://www.nerdfonts.com/) — this config defaults to **CodeNewRoman Nerd Font** (`ThemeEngine.fontFamily`)
- [alacritty](https://alacritty.org/) (or change `Niri.terminal` in `shell/services/Niri.qml`)

### Bar / OSD / system services

| Need | Used for |
|------|----------|
| `brightnessctl` | Brightness widget + OSD |
| NetworkManager | Network widget (`Quickshell.Networking`) |
| UPower | Battery widget (`Quickshell.Services.UPower`) |
| PipeWire | Volume widget + OSD (`Quickshell.Services.Pipewire`) |
| BlueZ stack | Bluetooth widget (`Quickshell.Bluetooth`) |
| `lm_sensors` (`sensors`) | CPU temperature |
| `top` / `free` | CPU / memory sampling in `services/SystemInfo.qml` |
| `gsettings` (GLib/dconf) | Prefer light/dark for GTK / libadwaita (and usually portals) |
| `qt6ct` | Prefer light/dark for Qt6 apps (`darker` / `airy` palettes) |

For Qt apps to follow qt6ct, the session needs `QT_QPA_PLATFORMTHEME=qt6ct` (e.g. in niri’s `environment { }`). Already-open Qt apps typically need a restart to pick up a palette change. Override the palette files via `ThemeEngine.qt6ctDarkPalette` / `qt6ctLightPalette` if you prefer different qt6ct color schemes.

### Bar click → TUI helpers

| Widget | Command |
|--------|---------|
| CPU / temperature | `btop` |
| Network | `nmtui` |
| Bluetooth | `bluetui` |
| Volume | `wiremix` |
| Clock | `minical` |

### Launcher extras

| Need | Used for |
|------|----------|
| `xdg-open` (`xdg-utils`) | Opening files / directories |
| `fd` | File / directory search |

### Greeter (optional)

| Need | Used for |
|------|----------|
| [greetd](https://github.com/kalyverse/greetd) | Login/auth backend (`Quickshell.Services.Greetd`) |
| [cage](https://github.com/cage-kiosk/cage) (or another minimal Wayland compositor) | Hosts the greeter as greetd's kiosk session |

## Layout

```
common/                shared code (no shell.qml of its own — not runnable directly)
  theme-switcher/      ThemeEngine, palettes, themes.json
  panel/               generic UI atoms: PanelSearchInput, PanelKeyHints, PanelSubtitle
shell/                 the main niri config (its own shell.qml)
  shell.qml            entrypoint
  bar/                 status bar + widgets/
  panel/               launcher + theme tabs
  notifications/       notification UI + service
  osd/                 volume / brightness OSD
  services/            Niri, SystemInfo, Time, Displays
  common                symlink -> ../common
greeter/               separate config for greetd (own shell.qml, common symlink -> ../common)
```

`shell/` and `greeter/` each reach `common/` through a single `common` symlink rather than plain relative imports — Quickshell sandboxes QML module resolution to each config's own directory, so a symlink *inside* the config folder is required (see `AGENTS.md` for the full explanation). Don't break these symlinks when moving files around; if you need to reuse something else across configs, move the real file into `common/` — relative imports inside `common/` keep working unmodified no matter where it's mounted.

## Greeter (greetd)

`greeter/` is a login screen for [greetd](https://github.com/kalyverse/greetd), separate from the main niri+Quickshell session — it's its own Quickshell config (own `shell.qml`), sharing `common/theme-switcher/` and a few generic `common/panel/` UI atoms with `shell/`.

### Setup

1. Install `greetd` and a minimal kiosk Wayland compositor to host the greeter, e.g. [cage](https://github.com/cage-kiosk/cage).
2. Deploy `common/` and `greeter/` as siblings somewhere the greeter's system user (commonly `greeter`) can read — it doesn't need the rest of this repo. `rsync -a` preserves the relative symlink between them as long as they stay siblings, and `--delete` keeps re-syncing after future edits clean (removes anything at the destination no longer in the source):
   ```bash
   sudo mkdir -p /etc/quickshell
   sudo rsync -a --delete common greeter /etc/quickshell/
   ```
   Re-run that same command any time `common/` or `greeter/` change to update the deployed copy.
3. Point greetd at it in `/etc/greetd/config.toml`:
   ```toml
   [default_session]
   command = "cage -s -d -- qs -p /etc/quickshell/greeter"
   user = "greeter"
   ```
   `-d` matters: without it, cage defaults to client-side decorations and Qt draws its own fallback titlebar around the window.
4. Enable greetd: `sudo systemctl enable --now greetd`.

By default the greeter launches `niri-session` on successful login (see `GreeterWindow.sessionCommand` in `greeter/GreeterWindow.qml`) — adjust if your session needs something else (e.g. `["dbus-run-session", "niri"]`).

Caveats:
- The greeter shares the same `ThemeEngine`/`Theme` code as the main shell, but its saved-theme state is per-config-instance — it has no access to your logged-in session's theme selection and just falls back to the first entry in `themes.json`.
- **Multi-monitor**: cage has no `wlr-layer-shell` support (unlike niri), so the greeter can't put separate content on each screen the way the main shell's bar/OSD/notifications do. Cage always maximizes its single window across the bounding box of every connected output (its default "extend" multi-monitor mode). `GreeterWindow.qml` works around this by keeping the whole window a flat `Theme.bgBase` background and confining the actual login UI to the sub-rectangle matching the largest connected screen — so any other screen just shows a plain on-theme background rather than stretched UI.

## Planned

- **Lockscreen** — a `lockscreen/` module using Quickshell's Wayland session-lock support, themed to match the bar/panel via `Theme.*` / `ThemeEngine.*`. Lives inside this same shell/session. Not implemented yet — see `AGENTS.md` for notes on how it'd be structured.

## Credits

Derived from [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config). Reworked for niri and extended with the panel features above.
