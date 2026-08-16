# AGENTS.md

Guidance for AI agents working in this repo. See `README.md` for user-facing docs.

## What this is

A [Quickshell](https://quickshell.outfoxxed.me/) (QML) desktop shell for the [niri](https://github.com/YaLTeR/niri) compositor: bar, launcher panel, notifications, OSD, wallpaper, theme switcher, lockscreen — plus a standalone greetd greeter that shares its theming/UI atoms with the main shell.

## Project priority: portability

The main goal across this whole project is being able to port it to a different Linux distro or machine with minimal friction. This is *why* the project leans on native Quickshell APIs and well-known, widely-packaged terminal tools instead of environment-specific integrations (e.g. `niri msg --json` over a dedicated Hyprland/i3 IPC module, `fd`/`xdg-open` over bespoke tooling, `gsettings`/`qt6ct` for light/dark over a single DE's proprietary settings store). When evaluating a new dependency or design choice, prefer the option that keeps the actual implementation (QML/Quickshell code) reusable as-is, even if the surrounding system tool is slightly less universally pre-installed — per-machine setup (packages, PAM config, session files) is expected and not itself a portability concern; what should port cleanly is the code.

```
common/                shared code, not a Quickshell config on its own (no shell.qml)
  theme/                ThemeEngine (singleton), ThemePalette, Theme, themes.json
  panel/                generic UI atoms: PanelSearchInput, PanelKeyHints, PanelSubtitle, AuthPrompt
  osd/                  OSDController (singleton), OSDHud, OSDPill — shared by session, lockscreen, greeter
niri/                   compositor config; each user symlinks ~/.config/niri here
shell/                  the main Quickshell config — its own Quickshell config (own shell.qml)
  shell.qml             entrypoint (Scope wiring the pieces below)
  bar/                  status bar + bar/widgets/ (one file per indicator)
  panel/                app launcher + theme browser; shared list/search components
  notifications/        notification popups + NotificationService singleton
  osd/                  session layer-shell OSD window (reads common/osd)
  wallpaper/            desktop wallpaper (Wallpaper + WallpaperController); Background layer, namespace "wallpaper"
  lockscreen/           Wayland session lock (Lockscreen, LockContext/PamContext, LockSurface)
  services/             singletons: Niri, SystemInfo, Time, Displays
  common                symlink -> ../common
greeter/                separate Quickshell config (own shell.qml) for greetd — see below
  common                symlink -> ../common
callie/                 git submodule: TUI calendar app (bar clock click-through), built by install.sh rust
systemd/                optional systemd user units (symlinked by install.sh) — see below
install.sh              optional setup script dispatcher: utils | shell | greeter | rust | all
install/                setup script parts: lib.sh (helpers), utils.sh, shell.sh, greeter.sh, rust.sh
```

### Sharing code between configs: one `common` symlink per config, plus `qs.` imports

Quickshell treats every directory containing its own `shell.qml` as an isolated root for QML module resolution — `import "../common/theme"` from inside `shell/` or `greeter/` does not resolve, even though both live in the same checkout (confirmed empirically: `qs -p greeter` logs `Module path ... is outside of the config folder` then fails to resolve the type). A **symlink placed inside the config's own directory** works fine, though, since the scanner only checks the textual import path, not where the symlink's target actually lives: `shell/common` and `greeter/common` both symlink to `../common`.

Imports use Quickshell's root-relative module syntax (`import qs.<path>`), which is what `qmlls` understands for singletons and completions. Path segments are dotted directories under the config root (`shell.qml`'s folder), e.g. `import qs.common.theme`, `import qs.services`, `import qs.bar.widgets`. Directory names must be valid QML module identifiers (no hyphens).

This means:
- **One symlink per config covers all of `common/`.** Earlier this project symlinked individual files/dirs at matching relative depth, which meant every file inside `common/` had to assume a specific depth from its symlinked location. Symlinking the whole `common/` directory as a single unit avoids that: `qs.common.*` imports resolve the same from `shell/` and `greeter/` because both mount `common/` at the same place relative to their `shell.qml`.
- **Only genuinely generic, session-agnostic code belongs in `common/`.** Currently: `theme/` (palette/typography engine), a small `panel/` subset (`PanelSearchInput.qml`, `PanelKeyHints.qml`, `PanelSubtitle.qml`, `AuthPrompt.qml` — the last used by both the greeter's `GreeterWindow.qml` and the main shell's `lockscreen/LockSurface.qml`), and `osd/` (`OSDController`, `OSDHud`, `OSDPill` — used by the session overlay, lock surface, and greeter). `panel/PanelList*.qml`, `ShellPanel*.qml`, `LauncherTab.qml`, `ThemeTab.qml`, and `wallpaper/` stay in `shell/` since nothing outside the main shell uses them yet; move more into `common/` the same way if something else needs them.
- Anything backed by a live user session (`services/Niri.qml`, `services/SystemInfo.qml`, `notifications/`) is not reusable by the greeter even in principle — there's no niri session or logged-in processes to query pre-login. Volume/brightness OSD is an exception: PipeWire + `brightnessctl` can still be useful on the greeter if those are available in the greetd/cage environment.

## Conventions

- Prefer `import qs.<path>` over quoted relative directory imports (`import "../foo"`). Create an empty `.qmlls.ini` next to each config's `shell.qml` (gitignored; Quickshell populates it) so `qmlls` can resolve singletons. Same-directory singletons/types still need an explicit `import qs.<this.module>` for the LSP (runtime implicit imports are not enough) — e.g. `OSDHud.qml` does `import qs.common.osd` to see `OSDController.*`.
- Singletons (`pragma Singleton`) live in `shell/services/`, `shell/wallpaper/`, `common/theme/`, and `common/osd/`; widgets read them directly (e.g. `Theme.textPrimary`, `ThemeEngine.fontFamily`, `Niri.workspaces`, `OSDController.showVolume`, `WallpaperController.source`) rather than passing props down.
- Bar widgets are self-contained files in `shell/bar/widgets/`, built on `BarPill.qml` / `IconTextBarPill.qml`. Follow the existing widget style when adding one.
- System calls go through `Quickshell.Io` `Process` + `StdioCollector`, or `Quickshell.execDetached(...)` for fire-and-forget commands. Shell one-liners are passed as `["sh", "-c", "..."]`; keep user-controlled input passed as separate argv entries (`$1`, `$2`, ...), not string-interpolated into the script, to avoid injection.
- Config-relative paths use `Quickshell.shellPath(...)`; persisted state (e.g. selected theme) uses `Quickshell.statePath(...)` so the checkout can run from any location via `qs -p`.
- Panel search/list UI (`shell/panel/ShellPanelTab.qml`, `PanelList.qml`, `PanelListItem.qml`, etc.) is shared between the launcher and theme tabs — prefer extending the shared components over forking them.
- `ListView.currentIndex` should never be a plain `currentIndex: selectedIndex` binding in this codebase — Quickshell/Qt can silently reassign it when the model is diffed (e.g. live filtering), which permanently breaks that binding. Push it explicitly via `onSelectedIndexChanged`/`onCountChanged` handlers instead (see `shell/panel/PanelList.qml`).
- When editing a file reached through the `common` symlink (e.g. `shell/common/theme/ThemeEngine.qml`, `greeter/common/panel/PanelSearchInput.qml`), you're editing the real file under `common/` — that's intentional, edit it directly rather than "de-symlinking" it.

## Running / testing changes

There is no build step and no automated test suite — this is a live QML config.

- Run the main shell from the repo: `qs -p /path/to/this/repo/shell` (or `qs -c shell`/bare `qs`/`quickshell` if checked out at `~/.config/quickshell`, since niri's `environment { QS_CONFIG_NAME "shell" }` sets the default — see `README.md`).
- Run the greeter the same way: `qs -p /path/to/this/repo/greeter` (or `-c greeter`).
- Quickshell hot-reloads on file save; watch its stdout/stderr for QML errors after edits.
- Sanity-check with `qs ipc call <target> <function>` for the various `IpcHandler`s (`bar`, `launcher`, `theme`, `font`, `notifications`, `lockscreen`, `wallpaper`) rather than only relying on visual testing. `qs ipc call lockscreen lock` is the only way to trigger the lockscreen without a real idle daemon/keybind.
- There's no linter config in-repo; keep QML formatting consistent with surrounding code (2-space indent is inconsistent across files already — match the file you're editing).

## `shell/lockscreen/` — session lock (implemented)

Lives inside the main shell/session, wired into `shell/shell.qml` alongside `Bar`/`ShellPanel`/etc. (not a separate Quickshell config, unlike `greeter/`). Reuses the greeter's visual design via the shared `common/panel/AuthPrompt.qml`, but authenticates the current user instead of driving a login flow.

- **Session lock**: `Lockscreen.qml` is a `Scope` holding a `Quickshell.Wayland.WlSessionLock` (`ext_session_lock_v1`) rather than shelling out to something like `swaylock` — matches the project's native-Quickshell-API preference. `LockSurface.qml` is the per-screen content, instantiated once per screen by `WlSessionLock`'s `surface` component.
- **Auth backend**: `LockContext.qml` wraps a `Quickshell.Services.Pam` `PamContext` (`user: Quickshell.env("USER")`, `start()`/`respond()`/`onPamMessage`/`onCompleted`) rather than hand-rolling PAM. Uses its own pam service, `shell/lockscreen/pam/auth.conf` (`auth required pam_unix.so`), instead of a system service like `login`/`sudo` — see `Quickshell.Services.Pam`'s docs on writing dedicated pam configs; a system service can carry unrelated behavior (failure delays, extra prompts) that's a bad fit here.
- **No username stage**: unlike the greeter, `LockSurface` always prompts for a password only, for the already-known `Quickshell.env("USER")` — there's exactly one user to unlock as.
- **Manual trigger**: `Lockscreen.qml` exposes `IpcHandler { target: "lockscreen" }` with a `lock()` function (`qs ipc call lockscreen lock`) for binding to a niri keybind or idle daemon. There is intentionally no `unlock()` counterpart in the IPC handler.
- **Security-critical**: `WlSessionLock.locked` must only ever be set back to `false` from `LockContext.onUnlocked` (i.e. a real `PamResult.Success`) — never wire a plain `closeRequested()`/Escape-key-style escape hatch into any of this, or the lock becomes bypassable. Per `WlSessionLock`'s own API, only one `WlSessionLock` may be locked at a time.

## `install.sh` + `systemd/` — optional machine setup (implemented)

`install.sh` at the repo root is a thin dispatcher (`utils|shell|greeter|rust|all` subcommand, `all` by default) that sources `install/lib.sh` (shared helpers: `warn`, `ensure_symlink`) plus `install/{utils,shell,greeter,rust}.sh`, each of which defines its own `run_*` entrypoint. These cover independent pieces of per-machine setup — keep all of them in mind if extending any:

- **`install/utils.sh` (`run_utils` → `check_dependencies`)**: reports which CLI tools the QML/`install.sh` actually invoke are on `PATH`. Keep this list aligned with real `Process`/`execDetached`/`openFloatingTui` call sites (and README's CLI tables) when adding a new hard runtime dep — don't invent `command -v` checks for stacks only used via Quickshell modules (NetworkManager, UPower, PipeWire, BlueZ, PAM).
- **`install/shell.sh` (`run_shell` → `link_niri_config`, `install_systemd_units`)**:
  - `link_niri_config` symlinks `${XDG_CONFIG_HOME:-$HOME/.config}/niri` to this checkout's `niri/`, for the user running the script — backing up any pre-existing non-symlink directory first (with confirmation) and re-linking a stale symlink automatically. Deliberately per-user, not machine-wide: run this once per account that should log into niri via this repo's config, including any account that logs in through the shared greeter (see below).
  - `install_systemd_units` symlinks `systemd/quickshell.service` and `systemd/swayidle.service` into `~/.config/systemd/user/`, and writes `~/.config/quickshell/session.env` (`QS_CONFIG_PATH=…`) that both units load via `EnvironmentFile=%E/quickshell/session.env` — niri's config-level `environment {}` block doesn't propagate to systemd-started units, only to niri's own direct children, so the path can't just be inherited. Edit the units in-repo; only re-run `install.sh shell` (or rewrite `session.env`) when the checkout moves.
- **`install/greeter.sh` (`run_greeter` → `deploy_greeter_files`, `configure_greetd`, `enable_greetd`)**: rsyncs `common/` + `greeter/` to `/etc/quickshell/` (must stay a real copy — the `greeter` user usually can't read `$HOME`, and the greeter runs before login), symlinks [`greeter/config.toml`](greeter/config.toml) to `/etc/greetd/config.toml` (prompts before replacing a pre-existing real file; greetd reads it as root so the symlink is fine), and enables `greetd`. Edit the in-repo `greeter/config.toml` when the desired greetd session command changes — the symlink means there's no second copy to keep in sync.
- **`install/rust.sh` (`run_rust` → `sync_callie_submodule`, `build_callie`, `check_cargo_tool_update`, `install_cargo_tools`)**: `sync_callie_submodule` runs `git submodule update --init --recursive -- callie` — it does NOT add the submodule to `.gitmodules` (that's a one-time manual `git submodule add`, see README.md); if the submodule isn't registered yet it warns and skips the build rather than failing the whole `install.sh` run. `build_callie` runs `cargo build --release` inside `callie/` and `sudo install -m 755`s the resulting binary to `/usr/local/bin/callie`. `wlctl`/`bluetui` are pinned to known-good versions via `WLCTL_VERSION`/`BLUETUI_VERSION` (plain vars at the top of the file, e.g. `0.1.9`/`0.8.0`) rather than tracked at latest — the crates.io equivalent of `callie`'s pinned submodule SHA; bump them with a deliberate edit + commit, never automatically. `check_cargo_tool_update` (called once per tool from `install_cargo_tools`, before installing) hits the crates.io API (`curl`, with a descriptive User-Agent — crates.io 403s requests without one) for each pinned tool's `max_stable_version` and warns, non-fatally, if it differs from the pin; it never bumps anything itself, and is guarded (`command -v curl`, `|| true` on the curl pipeline) so a missing `curl` or a network hiccup can't trip the top-level `set -e` and abort the whole `install.sh` run. `install_cargo_tools` then first `cargo uninstall`s any pre-existing `~/.cargo/bin` copies of `wlctl`/`bluetui` (so there's only ever one copy on `PATH`), builds `wlctl@$WLCTL_VERSION bluetui@$BLUETUI_VERSION` unprivileged via `cargo install --root "${XDG_CACHE_HOME:-$HOME/.cache}/shell-install/cargo-root"` (a persistent cache dir, not a throwaway temp one, so re-runs get incremental rebuilds), and `sudo install -m 755`s the two resulting binaries into `/usr/local/bin` — same target directory as `callie`, so all three bar TUI helpers resolve from one system-wide location. cargo itself is never run under `sudo`.

`install/utils.sh` reports missing CLI tools; `install/shell.sh`, `install/greeter.sh`, and `install/rust.sh` do not re-gate on `command -v` — they just run, and `set -euxo pipefail` (`-x` for command tracing) fails the script on the first real error. The intentional soft-skips are `link_niri_config` and `configure_greetd` (each asks before replacing a pre-existing real path with a symlink), and `sync_callie_submodule` (warns and skips the `callie` build if the submodule hasn't been `git submodule add`ed yet, rather than treating that as a fatal error).

See README.md's "Setup script" section for the full behavior, including the `niri.service` override caveat — a full override file replaces the packaged unit's `BindsTo=graphical-session.target` rather than merging with it, which would silently break the `shell` part.

## `greeter/` — display manager greeter (implemented)

A separate Quickshell config (its own `shell.qml`), living in `greeter/` in this same repo, sharing `common/theme/` and `common/panel/`'s generic atoms with `shell/` via the symlink mechanism described above. It runs *before* login, driven by [greetd](https://github.com/kalyverse/greetd), inside its own minimal compositor session (e.g. [cage](https://github.com/cage-kiosk/cage)) — not inside the user's niri+Quickshell session. It is **not** added to `shell/shell.qml`; it's launched independently (e.g. `qs -p /path/to/repo/greeter`, or `-c greeter` if deployed under an XDG config dir as a named subconfig — see README.md for the full greetd/cage setup).

- **Auth/session backend**: uses Quickshell's built-in `Quickshell.Services.Greetd` module (`Greetd` singleton — `createSession`/`respond`/`cancelSession`/`launch`, plus `authMessage`/`authFailure`/`readyToLaunch`/`error` signals) rather than hand-rolling the greetd IPC wire protocol. No custom socket code needed.
- **Why greetd over SDDM/LightDM/GDM**: greetd has no opinionated theming system of its own — the greeter is just any program greetd launches. That means the actual UI stays 100% portable Quickshell/QML code (same as the rest of this repo), instead of a second theme implementation in SDDM's QML greeter API or LightDM's HTML/CSS/JS webkit2 greeter. This matches the project's portability priority above: greetd itself is somewhat less universally pre-packaged than mainstream DMs, but it's a small low-dependency binary (trivial to build from source if unavailable), and per-machine setup (PAM file, session command) is unavoidable with any DM choice — it's not a downside specific to greetd.
- **Files**: `greeter/shell.qml` (entrypoint), `greeter/GreeterWindow.qml` (`FloatingWindow` with the username → auth-prompt(s) → launch flow), plus `greeter/common` (symlink into `common/`, see above).
- **Session launch**: `GreeterWindow.sessionCommand` (default `["niri-session"]`) is passed to `Greetd.launch(...)` once `readyToLaunch` fires, with no explicit config path — niri resolves `~/.config/niri/config.kdl` on its own for whichever user `niri-session` actually launches as. That means picking up this repo's config is entirely down to that user's `~/.config/niri` being a symlink to this checkout's `niri/` (`install.sh shell`'s `link_niri_config`, run once per user — see above), not anything the greeter passes at launch time. This is also what makes the greeter safe for multiple accounts on one machine: there's no single machine-wide `NIRI_CONFIG`/path file to collide on, each user's symlink is independent. Override `sessionCommand` if niri needs a wrapper (`dbus-run-session`, etc.) on a given machine.
- **Deployment caveat**: greetd typically runs the greeter as a dedicated system user (often `greeter`), which likely can't read `/home/<you>/.config/quickshell`. Deploy both `common/` and `greeter/` (as siblings — the symlinks are relative) somewhere that user can read; `cp -r` preserves the relative symlinks as long as the sibling layout is kept. See README.md's setup steps.
- **Theme sync**: the greeter reads the same `ThemeEngine`/`Theme` singletons as the main shell, but selection is persisted with `Quickshell.statePath(...)` (per-config under `~/.local/state/quickshell/by-shell/<hash>/`). The greeter is a separate config root and usually runs as its own system user, so it does not see the session's saved theme/font and falls back to the first entry in `themes.json` / the engine default font. Syncing across greetd would need a fixed path both users can write (e.g. the old `/var/lib/quickshell` approach) — not worth the machine setup unless that becomes a real requirement.

## Gotchas

- Widgets assume specific CLI tools are on `PATH` (see README's dependency tables and `install/utils.sh`'s `check_dependencies`) — don't add new hard runtime deps without updating both. This now also covers build-time deps of `install/rust.sh` (`cargo`), not just widget runtime deps.
- `shell/services/Niri.qml` talks to niri over `niri msg --json ...` / event-stream; there's no Quickshell-native niri module, so don't expect `Quickshell.*` APIs for workspaces/windows.
- Theme colors come from `common/theme/themes.json` + `ThemePalette.qml`, not hardcoded hex values — new UI should read from `Theme.*`.
- `common/` has no `shell.qml` and is never run directly — it's only ever reached through the symlinks in `shell/` and `greeter/`. Don't add a `shell.qml` there.
- niri's `spawn-at-startup "quickshell"` and the `qs ipc call ...` keybind (`niri/keybinds.kdl`) rely on `QS_CONFIG_NAME "shell"` being set in niri's `environment { }` block (`niri/main.kdl`) — without it they'd need an explicit `-c shell`, since there's no root `shell.qml` under `~/.config/quickshell` anymore.
