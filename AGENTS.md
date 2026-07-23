# AGENTS.md

Guidance for AI agents working in this repo. See `README.md` for user-facing docs.

## What this is

A [Quickshell](https://quickshell.outfoxxed.me/) (QML) desktop shell for the [niri](https://github.com/YaLTeR/niri) compositor: bar, launcher panel, notifications, OSD, theme switcher, lockscreen — plus a standalone greetd greeter that shares its theming/UI atoms with the main shell.

## Project priority: portability

The main goal across this whole project is being able to port it to a different Linux distro or machine with minimal friction. This is *why* the project leans on native Quickshell APIs and well-known, widely-packaged terminal tools instead of environment-specific integrations (e.g. `niri msg --json` over a dedicated Hyprland/i3 IPC module, `fd`/`xdg-open` over bespoke tooling, `gsettings`/`qt6ct` for light/dark over a single DE's proprietary settings store). When evaluating a new dependency or design choice, prefer the option that keeps the actual implementation (QML/Quickshell code) reusable as-is, even if the surrounding system tool is slightly less universally pre-installed — per-machine setup (packages, PAM config, session files) is expected and not itself a portability concern; what should port cleanly is the code.

```
common/                shared code, not a Quickshell config on its own (no shell.qml)
  theme-switcher/       ThemeEngine (singleton), ThemePalette, Theme, themes.json
  panel/                generic UI atoms: PanelSearchInput, PanelKeyHints, PanelSubtitle, AuthPrompt
  osd/                  OSDController (singleton), OSDHud, OSDPill — shared by session, lockscreen, greeter
niri/                   compositor config; each user symlinks ~/.config/niri here
shell/                  the main Quickshell config — its own Quickshell config (own shell.qml)
  shell.qml             entrypoint (Scope wiring the pieces below)
  bar/                  status bar + bar/widgets/ (one file per indicator)
  panel/                app launcher + theme browser; shared list/search components
  notifications/        notification popups + NotificationService singleton
  osd/                  session layer-shell OSD window (reads common/osd)
  lockscreen/           Wayland session lock (Lockscreen, LockContext/PamContext, LockSurface)
  services/             singletons: Niri, SystemInfo, Time, Displays
  common                symlink -> ../common
greeter/                separate Quickshell config (own shell.qml) for greetd — see below
  common                symlink -> ../common
systemd/                optional systemd user unit templates, rendered by install.sh — see below
install.sh              optional setup script: systemd units + greeter/greetd deployment
```

### Sharing code between configs: one `common` symlink per config, not plain relative imports

Quickshell treats every directory containing its own `shell.qml` as an isolated root for QML module resolution — `import "../common/theme-switcher"` from inside `shell/` or `greeter/` does not resolve, even though both live in the same checkout (confirmed empirically: `qs -p greeter` logs `Module path ... is outside of the config folder` then fails to resolve the type). A **symlink placed inside the config's own directory** works fine, though, since the scanner only checks the textual import path, not where the symlink's target actually lives: `shell/common` and `greeter/common` both symlink to `../common`, imported as `import "common/theme-switcher"` (or `"../common/theme-switcher"`, `"../../common/theme-switcher"`, etc. from a subdirectory, exactly as if `common/` were a real directory there).

This means:
- **One symlink per config covers all of `common/`.** Earlier this project symlinked individual files/dirs (`shell/theme-switcher`, `shell/panel/PanelSearchInput.qml`, ...) at matching relative depth, which meant every file inside `common/` had to assume a specific depth from its symlinked location. Symlinking the whole `common/` directory as a single unit avoids that: relative imports *within* `common/` (e.g. `common/panel/PanelSearchInput.qml`'s `import "../theme-switcher"`) resolve against `common/`'s own real internal layout no matter where `common/` itself is mounted, so they never need to change. Files *outside* `common/` just import through the one `common` symlink, e.g. `shell/panel/ShellPanelTab.qml` does `import "../common/panel"` to bring in `PanelSearchInput`/`PanelSubtitle`/`PanelKeyHints`, and `shell/bar/widgets/*.qml` does `import "../../common/theme-switcher"`.
- **Only genuinely generic, session-agnostic code belongs in `common/`.** Currently: `theme-switcher/` (palette/typography engine), a small `panel/` subset (`PanelSearchInput.qml`, `PanelKeyHints.qml`, `PanelSubtitle.qml`, `AuthPrompt.qml` — the last used by both the greeter's `GreeterWindow.qml` and the main shell's `lockscreen/LockSurface.qml`), and `osd/` (`OSDController`, `OSDHud`, `OSDPill` — used by the session overlay, lock surface, and greeter). `panel/PanelList*.qml`, `ShellPanel*.qml`, `LauncherTab.qml`, `ThemeTab.qml` stay in `shell/panel/` since nothing outside the main shell uses them yet; move more into `common/` the same way if something else needs them.
- Anything backed by a live user session (`services/Niri.qml`, `services/SystemInfo.qml`, `notifications/`) is not reusable by the greeter even in principle — there's no niri session or logged-in processes to query pre-login. Volume/brightness OSD is an exception: PipeWire + `brightnessctl` can still be useful on the greeter if those are available in the greetd/cage environment.

## Conventions

- Singletons (`pragma Singleton`) live in `shell/services/`, `common/theme-switcher/`, and `common/osd/`; widgets read them directly (e.g. `Theme.textPrimary`, `ThemeEngine.fontFamily`, `Niri.workspaces`, `OSDController.showVolume`) rather than passing props down.
- Bar widgets are self-contained files in `shell/bar/widgets/`, built on `BarPill.qml` / `IconTextBarPill.qml`. Follow the existing widget style when adding one.
- System calls go through `Quickshell.Io` `Process` + `StdioCollector`, or `Quickshell.execDetached(...)` for fire-and-forget commands. Shell one-liners are passed as `["sh", "-c", "..."]`; keep user-controlled input passed as separate argv entries (`$1`, `$2`, ...), not string-interpolated into the script, to avoid injection.
- Config-relative paths use `Quickshell.shellPath(...)`; persisted state (e.g. selected theme) uses `Quickshell.statePath(...)` so the checkout can run from any location via `qs -p`.
- Panel search/list UI (`shell/panel/ShellPanelTab.qml`, `PanelList.qml`, `PanelListItem.qml`, etc.) is shared between the launcher and theme tabs — prefer extending the shared components over forking them.
- `ListView.currentIndex` should never be a plain `currentIndex: selectedIndex` binding in this codebase — Quickshell/Qt can silently reassign it when the model is diffed (e.g. live filtering), which permanently breaks that binding. Push it explicitly via `onSelectedIndexChanged`/`onCountChanged` handlers instead (see `shell/panel/PanelList.qml`).
- When editing a file reached through the `common` symlink (e.g. `shell/common/theme-switcher/ThemeEngine.qml`, `greeter/common/panel/PanelSearchInput.qml`), you're editing the real file under `common/` — that's intentional, edit it directly rather than "de-symlinking" it.

## Running / testing changes

There is no build step and no automated test suite — this is a live QML config.

- Run the main shell from the repo: `qs -p /path/to/this/repo/shell` (or `qs -c shell`/bare `qs`/`quickshell` if checked out at `~/.config/quickshell`, since niri's `environment { QS_CONFIG_NAME "shell" }` sets the default — see `README.md`).
- Run the greeter the same way: `qs -p /path/to/this/repo/greeter` (or `-c greeter`).
- Quickshell hot-reloads on file save; watch its stdout/stderr for QML errors after edits.
- Sanity-check with `qs ipc call <target> <function>` for the various `IpcHandler`s (`bar`, `launcher`, `theme`, `font`, `notifications`, `lockscreen`) rather than only relying on visual testing. `qs ipc call lockscreen lock` is the only way to trigger the lockscreen without a real idle daemon/keybind.
- There's no linter config in-repo; keep QML formatting consistent with surrounding code (2-space indent is inconsistent across files already — match the file you're editing).

## `shell/lockscreen/` — session lock (implemented)

Lives inside the main shell/session, wired into `shell/shell.qml` alongside `Bar`/`ShellPanel`/etc. (not a separate Quickshell config, unlike `greeter/`). Reuses the greeter's visual design via the shared `common/panel/AuthPrompt.qml`, but authenticates the current user instead of driving a login flow.

- **Session lock**: `Lockscreen.qml` is a `Scope` holding a `Quickshell.Wayland.WlSessionLock` (`ext_session_lock_v1`) rather than shelling out to something like `swaylock` — matches the project's native-Quickshell-API preference. `LockSurface.qml` is the per-screen content, instantiated once per screen by `WlSessionLock`'s `surface` component.
- **Auth backend**: `LockContext.qml` wraps a `Quickshell.Services.Pam` `PamContext` (`user: Quickshell.env("USER")`, `start()`/`respond()`/`onPamMessage`/`onCompleted`) rather than hand-rolling PAM. Uses its own pam service, `shell/lockscreen/pam/auth.conf` (`auth required pam_unix.so`), instead of a system service like `login`/`sudo` — see `Quickshell.Services.Pam`'s docs on writing dedicated pam configs; a system service can carry unrelated behavior (failure delays, extra prompts) that's a bad fit here.
- **No username stage**: unlike the greeter, `LockSurface` always prompts for a password only, for the already-known `Quickshell.env("USER")` — there's exactly one user to unlock as.
- **Manual trigger**: `Lockscreen.qml` exposes `IpcHandler { target: "lockscreen" }` with a `lock()` function (`qs ipc call lockscreen lock`) for binding to a niri keybind or idle daemon. There is intentionally no `unlock()` counterpart in the IPC handler.
- **Security-critical**: `WlSessionLock.locked` must only ever be set back to `false` from `LockContext.onUnlocked` (i.e. a real `PamResult.Success`) — never wire a plain `closeRequested()`/Escape-key-style escape hatch into any of this, or the lock becomes bypassable. Per `WlSessionLock`'s own API, only one `WlSessionLock` may be locked at a time.

## `install.sh` + `systemd/` — optional machine setup (implemented)

`install.sh` lives at the repo root (not under `systemd/`) since it covers independent pieces of per-machine setup — keep all of them in mind if extending any:

- **Dependency check (`check_dependencies`)**: Step 0 reports which CLI tools the QML/`install.sh` actually invoke are on `PATH`. Keep this list aligned with real `Process`/`execDetached`/`openFloatingTui` call sites (and README's CLI tables) when adding a new hard runtime dep — don't invent `command -v` checks for stacks only used via Quickshell modules (NetworkManager, UPower, PipeWire, BlueZ, PAM).
- **niri config symlink (`link_niri_config`)**: Step 1 symlinks `${XDG_CONFIG_HOME:-$HOME/.config}/niri` to this checkout's `niri/`, for the user running the script — backing up any pre-existing non-symlink directory first (with confirmation) and re-linking a stale symlink automatically. Deliberately per-user, not machine-wide: run this once per account that should log into niri via this repo's config, including any account that logs in through the shared greeter (see below).
- **`systemd/quickshell.service` + `systemd/swayidle.service`**: templates for running quickshell and the lockscreen's idle daemon as systemd user services tied to `graphical-session.target`, as an alternative to niri's `spawn-at-startup`. They contain a literal `@QUICKSHELL_SHELL_PATH@` placeholder instead of a real path — `install.sh` substitutes the checkout's actual path at install time (niri's config-level `environment {}` block doesn't propagate to systemd-started units, only to niri's own direct children, so this can't just be inherited). Don't hand-edit that placeholder out of the checked-in templates; `install.sh` is what fills it in per-machine.
- **Greeter deployment**: rsyncs `common/` + `greeter/` to `/etc/quickshell/`, copies [`greeter/config.toml`](greeter/config.toml) to `/etc/greetd/config.toml` (prompts to overwrite or skip if that file already exists), and enables `greetd`. Edit the in-repo `greeter/config.toml` when the desired greetd session command changes — don't keep a second copy of that TOML elsewhere in the script.

Structured as small functions (`check_dependencies`, `link_niri_config`, `install_systemd_units`, `deploy_greeter_files`, `configure_greetd`, `enable_greetd`). Step 0 reports missing CLI tools; Steps 1–3 do not re-gate on `command -v` — they just run, and `set -euxo pipefail` (`-x` for command tracing) fails the script on the first real error. The intentional soft-skips are `link_niri_config` (asks before replacing a pre-existing real `~/.config/niri`) and `configure_greetd` (offers to skip when `/etc/greetd/config.toml` already exists).

See README.md's "Setup script" section for the full behavior, including the `niri.service` override caveat — a full override file replaces the packaged unit's `BindsTo=graphical-session.target` rather than merging with it, which would silently break the systemd step.

## `greeter/` — display manager greeter (implemented)

A separate Quickshell config (its own `shell.qml`), living in `greeter/` in this same repo, sharing `common/theme-switcher/` and `common/panel/`'s generic atoms with `shell/` via the symlink mechanism described above. It runs *before* login, driven by [greetd](https://github.com/kalyverse/greetd), inside its own minimal compositor session (e.g. [cage](https://github.com/cage-kiosk/cage)) — not inside the user's niri+Quickshell session. It is **not** added to `shell/shell.qml`; it's launched independently (e.g. `qs -p /path/to/repo/greeter`, or `-c greeter` if deployed under an XDG config dir as a named subconfig — see README.md for the full greetd/cage setup).

- **Auth/session backend**: uses Quickshell's built-in `Quickshell.Services.Greetd` module (`Greetd` singleton — `createSession`/`respond`/`cancelSession`/`launch`, plus `authMessage`/`authFailure`/`readyToLaunch`/`error` signals) rather than hand-rolling the greetd IPC wire protocol. No custom socket code needed.
- **Why greetd over SDDM/LightDM/GDM**: greetd has no opinionated theming system of its own — the greeter is just any program greetd launches. That means the actual UI stays 100% portable Quickshell/QML code (same as the rest of this repo), instead of a second theme implementation in SDDM's QML greeter API or LightDM's HTML/CSS/JS webkit2 greeter. This matches the project's portability priority above: greetd itself is somewhat less universally pre-packaged than mainstream DMs, but it's a small low-dependency binary (trivial to build from source if unavailable), and per-machine setup (PAM file, session command) is unavoidable with any DM choice — it's not a downside specific to greetd.
- **Files**: `greeter/shell.qml` (entrypoint), `greeter/GreeterWindow.qml` (`FloatingWindow` with the username → auth-prompt(s) → launch flow), plus `greeter/common` (symlink into `common/`, see above).
- **Session launch**: `GreeterWindow.sessionCommand` (default `["niri-session"]`) is passed to `Greetd.launch(...)` once `readyToLaunch` fires, with no explicit config path — niri resolves `~/.config/niri/config.kdl` on its own for whichever user `niri-session` actually launches as. That means picking up this repo's config is entirely down to that user's `~/.config/niri` being a symlink to this checkout's `niri/` (`install.sh`'s `link_niri_config`, run once per user — see above), not anything the greeter passes at launch time. This is also what makes the greeter safe for multiple accounts on one machine: there's no single machine-wide `NIRI_CONFIG`/path file to collide on, each user's symlink is independent. Override `sessionCommand` if niri needs a wrapper (`dbus-run-session`, etc.) on a given machine.
- **Deployment caveat**: greetd typically runs the greeter as a dedicated system user (often `greeter`), which likely can't read `/home/<you>/.config/quickshell`. Deploy both `common/` and `greeter/` (as siblings — the symlinks are relative) somewhere that user can read; `cp -r` preserves the relative symlinks as long as the sibling layout is kept. See README.md's setup steps.
- **Theme sync**: the greeter reads the same `ThemeEngine`/`Theme` singletons as the main shell, and `common/theme-switcher/ThemeEngine.qml` persists the selected theme to a fixed system-wide path (`/var/lib/quickshell/theme.conf`) rather than `Quickshell.statePath(...)` (per-config-instance, scoped under `by-shell/<hash-of-config-path>`) or a `$HOME`-based path (the greeter usually runs as its own system user, e.g. `greeter`, with its own `$HOME`, so it'd never see your login user's file). A fixed path both processes can agree on regardless of which user runs them is the only thing that actually syncs across a real greetd deployment. Requires one-time per-machine setup this repo can't do for you: a dedicated group (e.g. `quickshell-theme`) containing both your login user and whichever user runs the greeter, owning `/var/lib/quickshell` with the setgid bit (`chmod 2775`) so it stays writable by exactly those accounts — see the setup commands in `common/theme-switcher/ThemeEngine.qml`'s comment above `sharedStateDir`.

## Gotchas

- Widgets assume specific CLI tools are on `PATH` (see README's dependency tables and `install.sh`'s `check_dependencies`) — don't add new hard runtime deps without updating both.
- `shell/services/Niri.qml` talks to niri over `niri msg --json ...` / event-stream; there's no Quickshell-native niri module, so don't expect `Quickshell.*` APIs for workspaces/windows.
- Theme colors come from `common/theme-switcher/themes.json` + `ThemePalette.qml`, not hardcoded hex values — new UI should read from `Theme.*`.
- `common/` has no `shell.qml` and is never run directly — it's only ever reached through the symlinks in `shell/` and `greeter/`. Don't add a `shell.qml` there.
- niri's `spawn-at-startup "quickshell"` and the `qs ipc call ...` keybind (`niri/keybinds.kdl`) rely on `QS_CONFIG_NAME "shell"` being set in niri's `environment { }` block (`niri/main.kdl`) — without it they'd need an explicit `-c shell`, since there's no root `shell.qml` under `~/.config/quickshell` anymore.
