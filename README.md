# quickshell (niri)

Personal [Quickshell](https://quickshell.org/) desktop shell for [niri](https://github.com/niri-wm/niri): status bar, launcher panel, notifications, and OSD.

## What's included

| Piece | Description |
|-------|-------------|
| **Bar** | Top bar with CPU, temperature, niri workspaces, now playing, window title, system tray, volume, brightness, network, bluetooth, battery, and clock |
| **Panel** | App launcher with calculator (`2+2`), run mode (`> command`), file search (`? query` or inline), system actions (lock / power / media), plus theme and font browsers |
| **Notifications** | Notification popups |
| **OSD** | Brief volume / brightness feedback |
| **Themes** | Large palette set with live preview and persistence |
| **Lockscreen** | Wayland session lock for the current user (`shell/lockscreen/`) — see below |
| **Greeter** | Optional standalone login screen for [greetd](https://github.com/kalyverse/greetd) (`greeter/`) — see below |

Bar widgets can open TUI tools in a floating terminal (alacritty by default). The bar auto-hides on a single monitor (hover or `qs ipc call bar peek`) and stays on the smallest screen when several are connected.

## Running

The main config lives in `shell/` (not at the repo root — see [Layout](#layout)), so it's run by path:

```bash
qs -p /path/to/this/repo/shell
```

At login the shell is started by the [niri config repo](https://github.com/thomaswallaceg/niri-config), cloned to `~/.config/niri`: its shell include runs `systemctl --user start thomas-shell.service`. Commenting out that one line is all it takes to stop this shell from starting.

What the compositor config has to provide, all of it in that repo's shell include:

- `spawn-at-startup "systemctl" "--user" "start" "thomas-shell.service"`
- keybinds calling `qs ipc call …` (launcher, lockscreen, media keys) and `lid-close` for the lock — see the IPC examples below
- a floating window rule matching the title `quickshell-tui-widget`, for the TUI tools the bar opens
- a layer rule for the `quickshell/wallpaper` namespace (niri: `place-within-backdrop`)
- the `cursor {}` block, matching the other two places listed under [Dependencies](#required)

Once installed (`./install.sh shell` or `make install-shell`), the session runs the installed copy, `$PREFIX/share/thomas-shell/shell`. `make` also installs `$PREFIX/lib/environment.d/60-thomas-shell.conf`, which sets `QS_CONFIG_PATH` for your whole systemd user session. That's how `thomas-shell.service` and niri's `qs ipc call …` keybinds all find the same shell without passing `-p`.

To develop, run the checkout by hand instead: `systemctl --user stop thomas-shell.service`, then `qs -p ./shell` from the repo, which hot-reloads on save. `qs ipc call …` from a terminal needs `-p ./shell` too while you do this, since `QS_CONFIG_PATH` still names the installed copy. `systemctl --user start thomas-shell.service` switches back.

Config-relative assets use `Quickshell.shellPath(...)`. The active theme id is stored under Quickshell's per-shell state directory, so the checkout does not need to live in `~/.config/quickshell`.

Running it as a systemd user service rather than a bare `spawn-at-startup` is what gets you `Restart=on-failure` and `systemctl`-level start/stop/logs; [`./install.sh shell`](#setup-script-installsh) installs the units.

Useful IPC (examples):

```bash
qs ipc call launcher toggle
qs ipc call theme toggle
qs ipc call font toggle
qs ipc call bar toggle
qs ipc call bar peek
qs ipc call wallpaper set /path/to/image.jpg
qs ipc call wallpaper clear
qs ipc call wallpaper pick
```

Launcher action **Set wallpaper** (search “wallpaper”) opens a Zenity file dialog and applies the chosen image.

Launcher action **Sync greeter theme and font** (search “greeter”) copies your current theme and font to the login screen. Your own theme/font choices only ever change your shell and lockscreen; the greeter is shared by every user, so changing it needs an admin's password. The action runs `shell/scripts/sync-greeter-preferences.sh` through `pkexec`, which checks the theme exists and writes `/etc/thomas-shell/greeter.json`. The greeter reads that file (read-only) and picks up changes on its next start. `make install-shell` installs a polkit policy for the script, so the password prompt says what it's for. It's a one-shot copy, not a live sync. No wallpaper equivalent yet; the greeter doesn't currently render one.

## Dependencies

### Required

- [Quickshell](https://quickshell.org/) (Qt 6)
- [niri](https://github.com/niri-wm/niri)
- A *Propo* [Nerd Font](https://www.nerdfonts.com/) — this config defaults to **CodeNewRoman Nerd Font Propo** (`ThemeEngine.fontFamily`)
- [alacritty](https://alacritty.org/) (or change `TuiWindows.terminal` in `shell/services/TuiWindows.qml`)
- The **Adwaita** cursor theme (`adwaita-cursors` on Arch, `adwaita-icon-theme` on Debian/Fedora). niri, the session environment (`environment.d/60-thomas-shell.conf`) and the greeter all set it at size 24 so the cursor looks the same everywhere. Change it in the niri config repo's `cursor {}` block, `systemd/environment.d/60-thomas-shell.conf` and `greeter/config.toml` together.

### Bar / OSD / system services

| Need | Used for |
|------|----------|
| `brightnessctl` | Brightness widget + OSD |
| NetworkManager | Network widget (`Quickshell.Networking`) |
| UPower (`upower` + `busctl`) | Battery widget (`Quickshell.Services.UPower`); right-click toggles charge limit via UPower D-Bus |
| power-profiles-daemon | Battery widget left-click cycles power-saver / balanced / performance (`PowerProfiles`) |
| PipeWire | Volume widget + OSD (`Quickshell.Services.Pipewire`) |
| BlueZ stack | Bluetooth widget (`Quickshell.Bluetooth`) |
| `lm_sensors` (`sensors`) | CPU temperature |
| `free` | Memory sampling in `services/SystemInfo.qml` (CPU uses `/proc/stat`) |
| `gsettings` (GLib/dconf) | Prefer light/dark for GTK / libadwaita (and usually portals) |
| `qt6ct` | Prefer light/dark for Qt6 apps (`darker` / `airy` palettes) |
| `zenity` | Wallpaper file picker (launcher action / `qs ipc call wallpaper pick`) |

For Qt apps to follow qt6ct, the session needs `QT_QPA_PLATFORMTHEME=qt6ct` (e.g. in niri’s `environment { }`). Already-open Qt apps typically need a restart to pick up a palette change. Override the palette files via `ThemeEngine.qt6ctDarkPalette` / `qt6ctLightPalette` if you prefer different qt6ct color schemes.

### Bar click → TUI helpers

| Widget | Command |
|--------|---------|
| CPU / temperature | `btop` |
| Network | `wlctl` |
| Bluetooth | `bluetui` |
| Volume | `wiremix` |
| Clock | `callie` |

`callie` is this repo's own project (a git submodule, `callie/`) — build+install it with `./install.sh rust`. `wlctl` and `bluetui` are third-party crates from crates.io, installed the same way via `cargo install`. `btop`/`wiremix` come from your distro's package manager and are out of scope for `install.sh`.

### Launcher extras

| Need | Used for |
|------|----------|
| `xdg-open` (`xdg-utils`) | Opening files / directories |
| `fd` | File / directory search |
| `qalc` (`libqalculate`) | Calculator — implicit multiplication, functions, units, etc. (`shell/services/Calculator.qml`) |
| `systemctl` | Power actions (suspend / reboot / shut down) |
| `systemd-inhibit` | Reboot/shutdown confirm when apps hold logind inhibitors |
| MPRIS (via Quickshell) | Play / pause / next / previous actions |
| PipeWire (via Quickshell) | Toggle mute action |
| `pkexec` | **Sync greeter theme and font** action (privilege escalation) |
| `jq` | **Sync greeter theme and font** action (`sync-greeter-preferences.sh`'s JSON edit) |

### Lockscreen

| Need | Used for |
|------|----------|
| PAM (`pam_unix.so`) | Password auth against the current user (`Quickshell.Services.Pam`) |
| A compositor with `ext_session_lock_v1` (niri has it) | Hosts the lock (`Quickshell.Wayland.WlSessionLock`) |
| `systemd-inhibit` (systemd) + `gdbus` (glib2) | Locking before sleep — see [Setup script](#setup-script-installsh) |

### Greeter (optional)

| Need | Used for |
|------|----------|
| [greetd](https://github.com/kalyverse/greetd) | Login/auth backend (`Quickshell.Services.Greetd`) |
| [cage](https://github.com/cage-kiosk/cage) (or another minimal Wayland compositor) | Hosts the greeter as greetd's kiosk session |

## Layout

```
common/                shared code (no shell.qml of its own — not runnable directly)
  theme/               ThemeEngine, palettes, themes.json
  panel/               generic UI atoms: PanelSearchInput, PanelKeyHints, PanelSubtitle, AuthPrompt
  osd/                 OSDController, OSDHud, OSDPill (session + lockscreen + greeter)
shell/                 the main Quickshell config (its own shell.qml)
  shell.qml            entrypoint
  bar/                 status bar + widgets/
  panel/               launcher + theme + font tabs
  notifications/       notification UI + service
  osd/                 session layer-shell OSD window
  wallpaper/           desktop wallpaper (Background layer-shell + WallpaperController)
  lockscreen/          session lock (Lockscreen, LockContext/PamContext, LockSurface)
  services/            Niri (compositor adapter), TuiWindows, IdleManager, SleepWatcher, SystemInfo, Time, Displays
  common                symlink -> ../common
greeter/               separate config for greetd (own shell.qml, common symlink -> ../common)
callie/                git submodule: TUI calendar app, built by install.sh rust
systemd/               systemd user units + environment.d (installed by make, started by the niri config; see below)
install.sh             optional setup script dispatcher: utils | shell | greeter | rust | all
Makefile               `make install[-shell|-greeter|-units|-doc]`: plain files under a prefix
polkit/                polkit action for the greeter theme sync script
install/               setup script parts: lib.sh (helpers), utils.sh, shell.sh, greeter.sh, rust.sh
```

`shell/` and `greeter/` each reach `common/` through a single `common` symlink — Quickshell sandboxes QML module resolution to each config's own directory, so a symlink *inside* the config folder is required (see `AGENTS.md` for the full explanation). QML files import modules with `import qs.<path>` (e.g. `import qs.common.theme`). Don't break these symlinks when moving files around; if you need to reuse something else across configs, move the real file into `common/`.

## Lockscreen

`shell/lockscreen/` locks the current session with a Wayland session lock (`Quickshell.Wayland.WlSessionLock`, `ext_session_lock_v1`), reusing the greeter's clock/card look (via the shared `common/panel/AuthPrompt.qml`) but authenticating the already logged-in user through PAM (`Quickshell.Services.Pam`) instead of greetd. It runs inside the main shell (`shell/shell.qml`), not as a separate config.

- Password-only, always for `Quickshell.env("USER")` — there's no username stage like the greeter's.
- Auth goes through a dedicated pam service, `shell/lockscreen/pam/auth.conf` (`auth required pam_unix.so`), rather than a system service like `login`/`sudo`, so it doesn't inherit unrelated behavior (extra prompts, failure delays) from those.
- Trigger a lock manually or from a keybind/idle daemon with:
  ```bash
  qs ipc call lockscreen lock
  ```
  There's intentionally no matching `unlock` IPC call — the only way out is a successful PAM authentication. A niri keybind for this, and idle-triggered auto-lock (see `shell/services/IdleManager.qml`), are set up by [`./install.sh`](#setup-script-installsh)'s systemd step; wire the keybind into `niri/keybinds.kdl` if it isn't already.

## Setup script (`install.sh`)

`./install.sh` is a small dispatcher over `install/{lib,utils,shell,greeter,rust}.sh`. Pick which part to run with a subcommand (default `all`):

```bash
./install.sh          # same as `all`
./install.sh utils    # dependency check only
./install.sh shell    # install the shell + systemd units only
./install.sh greeter  # greetd/cage deployment only
./install.sh rust     # build callie (submodule) + cargo-install wlctl/bluetui
```

- **`utils`** (`install/utils.sh`): reports which of the project's CLI tools are on `PATH` (`[ok]` / `[missing]`), mirroring the tools the QML actually invokes (`brightnessctl`, `fd`, `wlctl`, …) plus the `shell`/`greeter`/`rust` parts' own helpers (`systemctl`, `make`, `greetd`, `cage`, `cargo`, …). Non-fatal — most are per-widget/feature. Stacks consumed only via Quickshell modules (NetworkManager, UPower, power-profiles-daemon, PipeWire, BlueZ, PAM) are listed in the tables above, not here. Also runs automatically before `shell`/`greeter`/`rust` (once for `all`), so missing tools are listed up front; it only warns, and a missing required tool still just fails its command under `set -e`.
- **`shell`** (`install/shell.sh`):
  - the niri config is its own repo, cloned to `~/.config/niri` per user (see [niri config repo](https://github.com/thomaswallaceg/niri-config)); this script doesn't touch it.
  - installs the shell and `systemd/thomas-shell.service` system-wide with `sudo make install-shell install-units` (to `$PREFIX/share/thomas-shell/shell` and `$PREFIX/lib/systemd/user`, which systemd searches for user units), plus the `environment.d` file that points `QS_CONFIG_PATH` at the installed shell. The session runs that installed copy, not the checkout, so re-run this step after changing the shell. Then `daemon-reload`s, which also re-reads `environment.d`. Log out and back in afterwards: a running niri keeps the `QS_CONFIG_PATH` it started with. The unit is never `enable`d: the niri config's shell include runs `systemctl --user start thomas-shell.service` at startup, and `PartOf=graphical-session.target` stops it again at logout. Running quickshell as a systemd **user** service rather than a bare `spawn-at-startup` gets you `Restart=on-failure` and `systemctl --user status/restart/...`; commenting out that one line in the niri config disables the whole thing.
  - Idle-triggered lock / display power-off / suspend is handled by the shell itself — see `shell/services/IdleManager.qml`, wired into `shell.qml`. It wraps Quickshell's own `IdleMonitor` (`ext-idle-notify-v1`) with timeouts bound live to `Quickshell.Services.UPower`'s `onBattery`: a tighter set (lock/monitors-off/suspend at 5/5.5/10 min) on battery, relaxed (15/16/30 min) otherwise — and since it's a live QML binding rather than a value picked once at process start, plugging in or unplugging takes effect immediately, no restart needed. Suspends the shell didn't trigger (lid close, `systemctl suspend`, low battery) are covered by `shell/services/SleepWatcher.qml`, which holds a logind delay inhibitor and, when logind announces `PrepareForSleep`, blanks the monitors and locks before letting the machine sleep — blanking first so the lockscreen doesn't flash on the way down. On resume it powers the monitors back on.
- **`greeter`** (`install/greeter.sh`): runs `sudo make install-greeter` to install `common/` + `greeter/` under `$PREFIX/share/thomas-shell/` (default `/usr/local`; set `PREFIX` in the environment to change it). That's a real copy readable by the `greeter` system user, which usually can't see your home directory. It then symlinks the installed `greeter/config.toml` to `/etc/greetd/config.toml` (prompts before replacing a pre-existing real file), and enables `greetd`.
- **`rust`** (`install/rust.sh`): checks out this repo's `callie/` git submodule, builds it with `cargo build --release`, and installs the resulting binary to `/usr/local/bin/callie` (needs `sudo`). Also builds the two third-party crates.io TUI tools `wlctl`/`bluetui`, pinned to known-good versions (`WLCTL_VERSION`/`BLUETUI_VERSION` at the top of `install/rust.sh`, e.g. `wlctl@0.1.9`) rather than tracked at latest — same reproducibility goal as `callie`'s pinned submodule commit, just via a plain version string instead of a git SHA since these aren't part of this repo. Built unprivileged into a persistent cache dir (`${XDG_CACHE_HOME:-$HOME/.cache}/shell-install/cargo-root`, so re-runs get incremental rebuilds), then installed to `/usr/local/bin` the same way as `callie` — so all three bar TUI helpers live in one system-wide location rather than a per-user `~/.cargo/bin`. Drops any pre-existing plain `cargo install` copies from `~/.cargo/bin` first, so there's exactly one copy of each on `PATH`. Before installing, it checks crates.io for a newer release of each pinned tool and prints a non-fatal warning if one exists (never bumps the pin itself — that's a deliberate edit + commit to `install/rust.sh`, same as bumping the `callie` submodule). `btop`/`wiremix` are left to your distro's package manager and aren't touched by this step.

  **One-time prerequisite**, before `rust` can build `callie` for the first time: `install.sh` never edits `.gitmodules` itself, so add the submodule once from the repo root:
  ```bash
  git submodule add https://github.com/thomaswallaceg/callie.git callie
  git commit -m "Add callie as a submodule"
  ```
  (Use `https://`, not `git@` — it works anonymously against a public repo on any machine, without that machine needing GitHub SSH keys configured.) After that one-time commit, a fresh `git clone` of this repo — even without `--recurse-submodules` — followed by `./install.sh rust` still works: the step runs `git submodule update --init --recursive` automatically every time. If the submodule hasn't been added yet, `rust` warns and skips the `callie` build rather than failing.

Run it from the repo root after changing the shell, greeter or units, to reinstall them.

Two things it can't do for you:
- **Set up the niri config**: it's a separate repo, cloned to `~/.config/niri` per user ([niri config repo](https://github.com/thomaswallaceg/niri-config)), and it's what starts the shell and carries the `qs ipc` keybinds.
- **The units need `niri.service` to still pull in `graphical-session.target`** (`BindsTo=graphical-session.target` / `Before=graphical-session.target` in the packaged unit) — if you have a **full override** at `~/.config/systemd/user/niri.service` rather than a `niri.service.d/*.conf` drop-in, double check it didn't drop those lines; a full override *replaces* the packaged unit instead of merging with it.

## Installing with `make`

The `Makefile` puts the shell, greeter and systemd user units under a prefix using the usual conventions (`PREFIX`, default `/usr/local`; `DESTDIR` for staging; `SYSTEMDUSERUNITDIR` if your distro puts user units somewhere other than `$PREFIX/lib/systemd/user`):

```bash
make                              # list targets
sudo make install                 # everything: /usr/local/share/thomas-shell/{shell,greeter,common}, units, docs
sudo make install-greeter         # one part: install-shell, install-greeter, install-units, install-doc
make install PREFIX=/usr DESTDIR=/tmp/stage   # staged install, e.g. from a distro package recipe
sudo make uninstall
make dist                         # thomas-shell-$VERSION.tar.gz of the committed tree
```

It only copies files: no prompts, no `systemctl`, nothing in `$HOME` or `/etc`. The `shell/`, `greeter/` and `common/` folders are replaced wholesale on each install, so files deleted from the repo disappear from the install too. Checked-in files that name the install location use `/usr/share/thomas-shell` (the `PREFIX=/usr` one), and the installed copies get it rewritten for the chosen prefix. `./install.sh greeter` uses `install-greeter`; the `shell` step still runs the shell straight from the checkout. To run an installed shell instead, enable the installed units and set `QS_CONFIG_PATH` in niri's `environment {}` block to `$PREFIX/share/thomas-shell/shell`.

## Greeter (greetd)

`greeter/` is a login screen for [greetd](https://github.com/kalyverse/greetd), separate from the main niri+Quickshell session — it's its own Quickshell config (own `shell.qml`), sharing `common/theme/` and a few generic `common/panel/` UI atoms with `shell/`.

### Setup

Install `greetd` and a minimal kiosk Wayland compositor to host the greeter, e.g. [cage](https://github.com/cage-kiosk/cage), then run [`./install.sh`](#setup-script-installsh) as **each user** who should be able to log in this way — its `shell` part and `greeter` part need to run per-user and per-machine respectively; see below.

To do it by hand instead:
1. Clone the [niri config repo](https://github.com/thomaswallaceg/niri-config) to `~/.config/niri` for each user who logs in via this greeter (this is what makes login work for more than one account — see the note below):
   ```bash
   git clone https://github.com/thomaswallaceg/niri-config.git ~/.config/niri
   ```
2. Install `common/` and `greeter/` somewhere the greeter's system user (commonly `greeter`) can read:
   ```bash
   sudo make install-greeter        # /usr/local/share/thomas-shell/{greeter,common}
   ```
   Re-run this any time `common/` or `greeter/` change.
3. Symlink the installed greetd config (its `command` path is fixed up for the install prefix):
   ```bash
   sudo ln -s /usr/local/share/thomas-shell/greeter/config.toml /etc/greetd/config.toml
   ```
4. Enable greetd: `sudo systemctl enable --now greetd`.

By default the greeter launches `niri-session` on successful login, wrapped in `systemd-cat` so its output goes to the journal (`journalctl -t niri-session`) rather than flashing on the console (see `GreeterWindow.sessionCommand`). It doesn't pass niri any explicit config path — niri resolves `~/.config/niri/config.kdl` on its own for whichever user `niri-session` actually launches as, so step 1's symlink is what makes it pick up this repo's config instead of creating a fresh default. This is also what makes the greeter safe to share across multiple user accounts on one machine: each user's symlink is independent, so there's no single machine-wide config path to collide on. Override `sessionCommand` if your session needs a different wrapper (e.g. `["dbus-run-session", "niri"]`).

Caveats:
- The greeter shares the same `ThemeEngine`/`Theme` code as the main shell, but reads its theme and font from `/etc/thomas-shell/greeter.json` (written by the launcher's **Sync greeter theme and font** action). Without that file it falls back to the first entry in `themes.json`.
- **Multi-monitor**: cage has no `wlr-layer-shell` support (unlike niri), so the greeter can't put separate content on each screen the way the main shell's bar/OSD/notifications do. Cage always maximizes its single window across the bounding box of every connected output (its default "extend" multi-monitor mode). `GreeterWindow.qml` works around this by keeping the whole window a flat `Theme.bgBase` background and confining the actual login UI to the sub-rectangle matching the largest connected screen — so any other screen just shows a plain on-theme background rather than stretched UI.

## Credits

Derived from [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config). Reworked for niri and extended with the panel features above.
