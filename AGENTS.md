# AGENTS.md

Guidance for AI agents working in this repo. See `README.md` for user-facing docs.

## What this is

A [Quickshell](https://quickshell.outfoxxed.me/) (QML) desktop shell for the [niri](https://github.com/YaLTeR/niri) compositor: bar, launcher panel, notifications, OSD, theme switcher — plus a standalone greetd greeter that shares its theming/UI atoms with the main shell.

## Project priority: portability

The main goal across this whole project is being able to port it to a different Linux distro or machine with minimal friction. This is *why* the project leans on native Quickshell APIs and well-known, widely-packaged terminal tools instead of environment-specific integrations (e.g. `niri msg --json` over a dedicated Hyprland/i3 IPC module, `fd`/`xdg-open` over bespoke tooling, `gsettings`/`qt6ct` for light/dark over a single DE's proprietary settings store). When evaluating a new dependency or design choice, prefer the option that keeps the actual implementation (QML/Quickshell code) reusable as-is, even if the surrounding system tool is slightly less universally pre-installed — per-machine setup (packages, PAM config, session files) is expected and not itself a portability concern; what should port cleanly is the code.

```
common/                shared code, not a Quickshell config on its own (no shell.qml)
  theme-switcher/       ThemeEngine (singleton), ThemePalette, Theme, themes.json
  panel/                generic UI atoms: PanelSearchInput, PanelKeyHints, PanelSubtitle
shell/                  the main niri config — its own Quickshell config (own shell.qml)
  shell.qml             entrypoint (Scope wiring the pieces below)
  bar/                  status bar + bar/widgets/ (one file per indicator)
  panel/                app launcher + theme browser; shared list/search components
  notifications/        notification popups + NotificationService singleton
  osd/                  volume / brightness OSD
  services/             singletons: Niri, SystemInfo, Time, Displays
  common                symlink -> ../common
greeter/                separate Quickshell config (own shell.qml) for greetd — see below
```

### Sharing code between configs: one `common` symlink per config, not plain relative imports

Quickshell treats every directory containing its own `shell.qml` as an isolated root for QML module resolution — `import "../common/theme-switcher"` from inside `shell/` or `greeter/` does not resolve, even though both live in the same checkout (confirmed empirically: `qs -p greeter` logs `Module path ... is outside of the config folder` then fails to resolve the type). A **symlink placed inside the config's own directory** works fine, though, since the scanner only checks the textual import path, not where the symlink's target actually lives: `shell/common` and `greeter/common` both symlink to `../common`, imported as `import "common/theme-switcher"` (or `"../common/theme-switcher"`, `"../../common/theme-switcher"`, etc. from a subdirectory, exactly as if `common/` were a real directory there).

This means:
- **One symlink per config covers all of `common/`.** Earlier this project symlinked individual files/dirs (`shell/theme-switcher`, `shell/panel/PanelSearchInput.qml`, ...) at matching relative depth, which meant every file inside `common/` had to assume a specific depth from its symlinked location. Symlinking the whole `common/` directory as a single unit avoids that: relative imports *within* `common/` (e.g. `common/panel/PanelSearchInput.qml`'s `import "../theme-switcher"`) resolve against `common/`'s own real internal layout no matter where `common/` itself is mounted, so they never need to change. Files *outside* `common/` just import through the one `common` symlink, e.g. `shell/panel/ShellPanelTab.qml` does `import "../common/panel"` to bring in `PanelSearchInput`/`PanelSubtitle`/`PanelKeyHints`, and `shell/bar/widgets/*.qml` does `import "../../common/theme-switcher"`.
- **Only genuinely generic, session-agnostic code belongs in `common/`.** Currently: `theme-switcher/` (palette/typography engine) and a small `panel/` subset (`PanelSearchInput.qml`, `PanelKeyHints.qml`, `PanelSubtitle.qml` — used by both the launcher and the greeter). `panel/PanelList*.qml`, `ShellPanel*.qml`, `LauncherTab.qml`, `ThemeTab.qml` stay in `shell/panel/` since nothing outside the main shell uses them yet; move more into `common/` the same way if/when the greeter or a future lockscreen needs them.
- Anything backed by a live user session (`services/Niri.qml`, `services/SystemInfo.qml`, `notifications/`, `osd/`) is not reusable by the greeter even in principle — there's no niri session or logged-in processes to query pre-login.

## Conventions

- Singletons (`pragma Singleton`) live in `shell/services/` and `common/theme-switcher/`; widgets read them directly (e.g. `Theme.textPrimary`, `ThemeEngine.fontFamily`, `Niri.workspaces`) rather than passing props down.
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
- Sanity-check with `qs ipc call <target> <function>` for the various `IpcHandler`s (`bar`, `launcher`, `theme`, `notifications`) rather than only relying on visual testing.
- There's no linter config in-repo; keep QML formatting consistent with surrounding code (2-space indent is inconsistent across files already — match the file you're editing).

## Planned additions

- **Lockscreen** — expected to live in a new `shell/lockscreen/` directory, wired into `shell/shell.qml` alongside `Bar`/`ShellPanel`/etc. It runs *inside* this same shell/session, so it should follow all the existing conventions above: read `Theme.*`/`ThemeEngine.*` for styling, use the existing singletons where relevant (e.g. `Time` for a clock), and expose an `IpcHandler` if manual lock/unlock triggering is useful. Uses Quickshell's Wayland session-lock support (`Quickshell.Wayland`) rather than shelling out to something like `swaylock`. Security-sensitive: unlike other panels, it must not be dismissible by anything other than successful auth — don't wire a plain `closeRequested()`-style escape hatch into it. Not yet implemented.

## `greeter/` — display manager greeter (implemented)

A separate Quickshell config (its own `shell.qml`), living in `greeter/` in this same repo, sharing `common/theme-switcher/` and `common/panel/`'s generic atoms with `shell/` via the symlink mechanism described above. It runs *before* login, driven by [greetd](https://github.com/kalyverse/greetd), inside its own minimal compositor session (e.g. [cage](https://github.com/cage-kiosk/cage)) — not inside the user's niri+Quickshell session. It is **not** added to `shell/shell.qml`; it's launched independently (e.g. `qs -p /path/to/repo/greeter`, or `-c greeter` if deployed under an XDG config dir as a named subconfig — see README.md for the full greetd/cage setup).

- **Auth/session backend**: uses Quickshell's built-in `Quickshell.Services.Greetd` module (`Greetd` singleton — `createSession`/`respond`/`cancelSession`/`launch`, plus `authMessage`/`authFailure`/`readyToLaunch`/`error` signals) rather than hand-rolling the greetd IPC wire protocol. No custom socket code needed.
- **Why greetd over SDDM/LightDM/GDM**: greetd has no opinionated theming system of its own — the greeter is just any program greetd launches. That means the actual UI stays 100% portable Quickshell/QML code (same as the rest of this repo), instead of a second theme implementation in SDDM's QML greeter API or LightDM's HTML/CSS/JS webkit2 greeter. This matches the project's portability priority above: greetd itself is somewhat less universally pre-packaged than mainstream DMs, but it's a small low-dependency binary (trivial to build from source if unavailable), and per-machine setup (PAM file, session command) is unavoidable with any DM choice — it's not a downside specific to greetd.
- **Files**: `greeter/shell.qml` (entrypoint), `greeter/GreeterWindow.qml` (`FloatingWindow` with the username → auth-prompt(s) → launch flow), plus `greeter/common` (symlink into `common/`, see above).
- **Session launch**: `GreeterWindow.sessionCommand` (default `["niri"]`) is passed to `Greetd.launch(...)` once `readyToLaunch` fires. Override it if niri needs a wrapper (env setup, `dbus-run-session`, etc.) on a given machine.
- **Deployment caveat**: greetd typically runs the greeter as a dedicated system user (often `greeter`), which likely can't read `/home/<you>/.config/quickshell`. Deploy both `common/` and `greeter/` (as siblings — the symlinks are relative) somewhere that user can read; `cp -r` preserves the relative symlinks as long as the sibling layout is kept. See README.md's setup steps.
- **Theme sync caveat**: the greeter reads the same `ThemeEngine`/`Theme` singletons as the main shell, but `Quickshell.statePath(...)` is per-config-instance, so it has no access to your logged-in session's saved theme — it just falls back to the first entry in `themes.json` like a fresh install, same as `shell/` would with no saved state.

## Gotchas

- Widgets assume specific CLI tools are on `PATH` (see README's dependency tables) — don't add new hard runtime deps without noting them in `README.md`.
- `shell/services/Niri.qml` talks to niri over `niri msg --json ...` / event-stream; there's no Quickshell-native niri module, so don't expect `Quickshell.*` APIs for workspaces/windows.
- Theme colors come from `common/theme-switcher/themes.json` + `ThemePalette.qml`, not hardcoded hex values — new UI should read from `Theme.*`.
- `common/` has no `shell.qml` and is never run directly — it's only ever reached through the symlinks in `shell/` and `greeter/`. Don't add a `shell.qml` there.
- niri's `spawn-at-startup "quickshell"` and the `qs ipc call ...` keybind (`niri/keybinds.kdl`) rely on `QS_CONFIG_NAME "shell"` being set in niri's `environment { }` block (`niri/main.kdl`) — without it they'd need an explicit `-c shell`, since there's no root `shell.qml` under `~/.config/quickshell` anymore.
