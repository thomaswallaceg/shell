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
| **Lockscreen** | Wayland session lock for the current user (`shell/lockscreen/`) — see below |
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

Alternatively, `./install.sh` (see [Setup script](#setup-script-installsh)) can set quickshell up as a systemd user service instead of a bare `spawn-at-startup` — this gets you `Restart=on-failure` and `systemctl`-level start/stop/logs, at the cost of one extra setup step per machine.

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
| Network | `wlctl` |
| Bluetooth | `bluetui` |
| Volume | `wiremix` |
| Clock | `minical` |

### Launcher extras

| Need | Used for |
|------|----------|
| `xdg-open` (`xdg-utils`) | Opening files / directories |
| `fd` | File / directory search |

### Lockscreen

| Need | Used for |
|------|----------|
| PAM (`pam_unix.so`) | Password auth against the current user (`Quickshell.Services.Pam`) |
| A compositor with `ext_session_lock_v1` (niri has it) | Hosts the lock (`Quickshell.Wayland.WlSessionLock`) |
| [`swayidle`](https://github.com/swaywm/sway) (optional) | Idle-triggered auto-lock / display power-off — see [Setup script](#setup-script-installsh) |

### Greeter (optional)

| Need | Used for |
|------|----------|
| [greetd](https://github.com/kalyverse/greetd) | Login/auth backend (`Quickshell.Services.Greetd`) |
| [cage](https://github.com/cage-kiosk/cage) (or another minimal Wayland compositor) | Hosts the greeter as greetd's kiosk session |

## Layout

```
common/                shared code (no shell.qml of its own — not runnable directly)
  theme-switcher/      ThemeEngine, palettes, themes.json
  panel/               generic UI atoms: PanelSearchInput, PanelKeyHints, PanelSubtitle, AuthPrompt
shell/                 the main niri config (its own shell.qml)
  shell.qml            entrypoint
  bar/                 status bar + widgets/
  panel/               launcher + theme tabs
  notifications/       notification UI + service
  osd/                 volume / brightness OSD
  lockscreen/          session lock (Lockscreen, LockContext/PamContext, LockSurface)
  services/            Niri, SystemInfo, Time, Displays
  common                symlink -> ../common
greeter/               separate config for greetd (own shell.qml, common symlink -> ../common)
systemd/               optional systemd user unit templates, rendered by install.sh (see below)
install.sh             optional setup script: systemd units + greeter/greetd deployment
```

`shell/` and `greeter/` each reach `common/` through a single `common` symlink rather than plain relative imports — Quickshell sandboxes QML module resolution to each config's own directory, so a symlink *inside* the config folder is required (see `AGENTS.md` for the full explanation). Don't break these symlinks when moving files around; if you need to reuse something else across configs, move the real file into `common/` — relative imports inside `common/` keep working unmodified no matter where it's mounted.

## Lockscreen

`shell/lockscreen/` locks the current session with a Wayland session lock (`Quickshell.Wayland.WlSessionLock`, `ext_session_lock_v1`), reusing the greeter's clock/card look (via the shared `common/panel/AuthPrompt.qml`) but authenticating the already logged-in user through PAM (`Quickshell.Services.Pam`) instead of greetd. It runs inside the main shell (`shell/shell.qml`), not as a separate config.

- Password-only, always for `Quickshell.env("USER")` — there's no username stage like the greeter's.
- Auth goes through a dedicated pam service, `shell/lockscreen/pam/auth.conf` (`auth required pam_unix.so`), rather than a system service like `login`/`sudo`, so it doesn't inherit unrelated behavior (extra prompts, failure delays) from those.
- Trigger a lock manually or from a keybind/idle daemon with:
  ```bash
  qs ipc call lockscreen lock
  ```
  There's intentionally no matching `unlock` IPC call — the only way out is a successful PAM authentication. A niri keybind for this, and a ready-to-use `swayidle` idle timeout (lock, then power off the displays a bit later), are set up by [`./install.sh`](#setup-script-installsh)'s systemd step; wiring the keybind itself into your niri config is still a manual step, since niri's config lives outside this repo.

## Setup script (`install.sh`)

`./install.sh` automates the machine-level integrations below:

- **Step 0 — dependency check**: reports which of the project's CLI tools are on `PATH` (`[ok]` / `[missing]`), mirroring the tools the QML actually invokes (`brightnessctl`, `fd`, `wlctl`, …) plus this script's own helpers (`systemctl`, `rsync`, `swayidle`, `greetd`, `cage`, …). Non-fatal — most are per-widget/feature. Stacks consumed only via Quickshell modules (NetworkManager, UPower, PipeWire, BlueZ, PAM) are listed in the tables above, not here. Steps 1–2 do not re-check these; a missing required tool just fails the command under `set -e`.
- **Step 1 — systemd units**: renders `systemd/quickshell.service` and `systemd/swayidle.service` (filling in this checkout's actual path, since niri's own `environment {}` block in `main.kdl` only reaches processes niri spawns directly, not independently-started systemd units) into `~/.config/systemd/user/`, then `daemon-reload`s and wires them to start alongside `niri.service`. This runs quickshell and the lockscreen's idle daemon (`swayidle`) as systemd **user** services tied to `graphical-session.target` instead of niri's own `spawn-at-startup` — you get `Restart=on-failure` and `systemctl --user status/restart/...` for both, at the cost of this one setup step per machine.
- **Step 2 — greeter deployment**: deploys `common/` + `greeter/` to `/etc/quickshell/` (readable by the `greeter` system user, which usually can't see your home directory), installs [`greeter/config.toml`](greeter/config.toml) to `/etc/greetd/config.toml` (prompts to overwrite or skip if that file already exists), and enables `greetd`.

Run it any time the checkout changes location (it re-renders from the templates rather than editing the installed copies), from the repo root:

```bash
./install.sh
```

Two things it can't do for you, since they live outside this repo:
- **Remove `spawn-at-startup "quickshell"` from `~/.config/niri/main.kdl`** after step 1 — leaving it in starts quickshell twice.
- **The systemd step needs `niri.service` to still pull in `graphical-session.target`** (`BindsTo=graphical-session.target` / `Before=graphical-session.target` in the packaged unit) — if you have a **full override** at `~/.config/systemd/user/niri.service` rather than a `niri.service.d/*.conf` drop-in, double check it didn't drop those lines; a full override *replaces* the packaged unit instead of merging with it.

## Greeter (greetd)

`greeter/` is a login screen for [greetd](https://github.com/kalyverse/greetd), separate from the main niri+Quickshell session — it's its own Quickshell config (own `shell.qml`), sharing `common/theme-switcher/` and a few generic `common/panel/` UI atoms with `shell/`.

### Setup

Install `greetd` and a minimal kiosk Wayland compositor to host the greeter, e.g. [cage](https://github.com/cage-kiosk/cage), then run [`./install.sh`](#setup-script-installsh) — its "greeter deployment" step does the rest (deploying `common/` + `greeter/` to `/etc/quickshell/`, writing `/etc/greetd/config.toml`, enabling `greetd`).

To do it by hand instead:
1. Deploy `common/` and `greeter/` as siblings somewhere the greeter's system user (commonly `greeter`) can read — it doesn't need the rest of this repo. `rsync -a` preserves the relative symlink between them as long as they stay siblings, and `--delete` keeps re-syncing after future edits clean (removes anything at the destination no longer in the source):
   ```bash
   sudo mkdir -p /etc/quickshell
   sudo rsync -a --delete common greeter /etc/quickshell/
   ```
   Re-run that same command any time `common/` or `greeter/` change to update the deployed copy.
2. Install the greetd config (same contents as [`greeter/config.toml`](greeter/config.toml)):
   ```bash
   sudo cp greeter/config.toml /etc/greetd/config.toml
   ```
3. Enable greetd: `sudo systemctl enable --now greetd`.

By default the greeter launches `niri-session` on successful login (see `GreeterWindow.sessionCommand` in `greeter/GreeterWindow.qml`) — adjust if your session needs something else (e.g. `["dbus-run-session", "niri"]`).

Caveats:
- The greeter shares the same `ThemeEngine`/`Theme` code as the main shell, but its saved-theme state is per-config-instance — it has no access to your logged-in session's theme selection and just falls back to the first entry in `themes.json`.
- **Multi-monitor**: cage has no `wlr-layer-shell` support (unlike niri), so the greeter can't put separate content on each screen the way the main shell's bar/OSD/notifications do. Cage always maximizes its single window across the bounding box of every connected output (its default "extend" multi-monitor mode). `GreeterWindow.qml` works around this by keeping the whole window a flat `Theme.bgBase` background and confining the actual login UI to the sub-rectangle matching the largest connected screen — so any other screen just shows a plain on-theme background rather than stretched UI.

## Credits

Derived from [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config). Reworked for niri and extended with the panel features above.
