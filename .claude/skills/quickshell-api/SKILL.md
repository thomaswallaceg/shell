---
name: quickshell-api
description: Reference for Quickshell's QML API (singletons under Quickshell.*, IPC, module resolution) as used in this repo's shell/ and greeter/ configs. Load before writing or reviewing QML that touches Quickshell.Io, Quickshell.Services.*, Quickshell.Wayland, Quickshell.Widgets, IpcHandler, or Quickshell's own module/import system — anything importing something under `Quickshell`.
---

# Quickshell API reference (this repo)

Pinned to **Quickshell 0.3.0** (`quickshell --version`). Quickshell's API has moved between minor versions before — if the installed version has drifted from this, re-verify anything below against the live docs before trusting it (see "When this runs out" at the bottom).

This is a cheat sheet grounded in how *this repo* actually uses each API (grep the cited files for the real context), not the full Quickshell surface. It exists to stop me guessing at property/signal names for a framework with much less training-data coverage than mainstream Qt Quick.

## Module resolution — read this before adding any new QML file

Quickshell treats every directory containing its own `shell.qml` as an isolated root for QML module resolution. `import "../common/theme"` from inside `shell/` does **not** resolve, even though both live in the same checkout — confirmed empirically: `qs -p greeter` logs `Module path ... is outside of the config folder`. Only files reachable via a real filesystem path *inside* the config's own directory resolve — hence `shell/common` and `greeter/common` both being symlinks to `../common` (see `AGENTS.md` for the full rationale).

Two import styles exist:
- `import qs.<path>` — Quickshell's root-relative syntax. Path segments are dotted directories under the config root (`shell.qml`'s folder): `import qs.common.theme`, `import qs.services`, `import qs.bar.widgets`. Directory names must be valid QML identifiers (no hyphens). **Preferred** in this repo — `qmlls` needs it for completions/singletons.
- `import "../foo"` — quoted relative paths. Avoid; doesn't work across the symlink boundary and isn't what `qmlls` resolves.

Same-directory singletons still need an explicit `import qs.<this.module>` for the LSP even though the runtime resolves them implicitly — e.g. `OSDHud.qml` does `import qs.common.osd` to see `OSDController.*` even though both live in `common/osd/`.

Create an empty `.qmlls.ini` next to each config's `shell.qml` (gitignored, Quickshell populates it) so `qmlls` can resolve singletons.

## Core `Quickshell` singleton (`import Quickshell`)

Global helpers used throughout this repo instead of hand-rolled equivalents:

- `Quickshell.env(name)` — read an env var. Used by `LockContext.qml`/`GreeterWindow.qml` for `Quickshell.env("USER")`.
- `Quickshell.execDetached(["cmd", "arg1", "arg2"])` — fire-and-forget process launch, no output captured. Prefer this over `Process { running: true }` when you don't need stdout/exit status.
- `Quickshell.shellPath(...)` — resolve a path relative to the current config root. Use for anything the config ships (icons, sub-QML, pam configs) so it works regardless of where the checkout lives (`qs -p /any/path`).
- `Quickshell.statePath(...)` — a writable path for persisted state (e.g. selected theme), namespaced per-config under `~/.local/state/quickshell/by-shell/<hash>/`. This is *why* the greeter and main shell don't share saved theme selection — they're separate config roots with separate state dirs.
- `Quickshell.iconPath(...)` — icon lookup by name/theme.
- `Quickshell.screens` — list of connected screens (`Quickshell.screens.length` used in this repo for multi-monitor checks).

## `Quickshell.Io` — process/file I/O

- **`Process`**: declarative subprocess. Key properties: `command` (array — first element is argv0, e.g. `["niri", "msg", "--json", "workspaces"]`), `running` (bool — set true to launch, or toggle to relaunch), `stdout`/`stderr` (attach a parser). See `shell/services/Niri.qml` for the canonical pattern: one-shot queries (`running: true`, parse once via `onStreamFinished`) vs. the long-running event stream (`command: ["niri", "msg", "--json", "event-stream"]`, parsed incrementally).
- **`StdioCollector`**: attach to `Process.stdout`/`stderr` to buffer all output and fire `onStreamFinished(text)` once the stream closes. Used for one-shot JSON queries — see `Niri.qml`'s `workspacesProc`/`activeWindowProc`.
- **`SplitParser`**: attach to `stdout` to get called per-line/per-delimiter as output streams in, instead of waiting for the process to close — used for niri's `event-stream`, which never closes.
- **`FileView`**: read/write a file reactively from QML (used 6x in this repo — check current call sites with `grep -rn FileView shell/ common/` for the live pattern, e.g. theme JSON loading).
- Shell one-liners: pass as `["sh", "-c", "..."]`. **Security convention in this repo**: keep user-controlled input as separate argv entries (`$1`, `$2`, ...) passed via `Process.command`'s trailing array elements — never string-interpolated directly into the `-c` script — to avoid injection. See `AGENTS.md`'s Conventions section.

## `IpcHandler` — `qs ipc call <target> <function>`

Declare inside any QML file to expose callable functions to the `qs ipc call` CLI and to niri keybinds (`spawn "qs" "ipc" "call" "lockscreen" "lock"` — see `niri/keybinds.kdl`):

```qml
IpcHandler {
    target: "lockscreen"          // qs ipc call lockscreen <function>

    function lock(): void {       // qs ipc call lockscreen lock
        sessionLock.locked = true;
    }
}
```

Return-typed functions (`: void`, `: bool`, ...) are required — untyped functions aren't exposed. This repo has 8 `IpcHandler`s: `bar`, `launcher`, `theme`, `font`, `notifications`, `lockscreen`, `wallpaper`, plus one more — `grep -rn 'target: "' shell/ greeter/` for the current list before assuming a target name.

## `Quickshell.Wayland`

- **`WlSessionLock`**: wraps the `ext_session_lock_v1` Wayland protocol for a real compositor-level session lock (not a fake always-on-top window). `locked: bool` triggers/releases the lock. `surface:` is a component instantiated once per connected screen — put per-screen lock UI there. **Security-critical** (per `AGENTS.md`): `locked` must only ever be set back to `false` from a real successful auth callback (see `PamContext` below) — never wire a plain Escape-key/`closeRequested()` escape hatch, or the lock becomes bypassable. Only one `WlSessionLock` may be locked at a time system-wide.
- **`PanelWindow`** + **`Layer`**: layer-shell surfaces (bar, OSD, notifications, wallpaper). `Layer` sets the `wlr-layer-shell` stacking layer (`Layer.Top`, `Layer.Background`, etc.) — check the specific widget file for the layer/anchors/margins pattern already in use before introducing a new layer-shell surface, rather than reinventing it.

## `Quickshell.Services.Pam` — `PamContext`

Used by `shell/lockscreen/LockContext.qml` to authenticate the logged-in user without hand-rolling PAM:

```qml
PamContext {
    configDirectory: "pam"        // relative to this config root
    config: "auth.conf"           // shell/lockscreen/pam/auth.conf: `auth required pam_unix.so`
    user: Quickshell.env("USER")

    onPamMessage: {
        if (this.responseRequired)
            this.respond(root.currentText);          // send the password
        else if (this.message) {
            root.helpText = this.message;
            root.helpTextStatus = this.messageIsError ? "error" : "normal";
        }
    }

    onCompleted: result => {
        if (result === PamResult.Success) { /* unlock */ }
        else { /* wrong password */ }
    }
}
```

Call `.start()` to begin an auth attempt. Use a **dedicated pam service file** (own `configDirectory`/`config`) rather than a system service like `login`/`sudo` — those can carry unrelated behavior (failure delays, extra prompts) that's a bad fit for a lockscreen/greeter prompt. `PamResult` is an enum (`PamResult.Success` confirmed used; check Quickshell docs for the full enum if handling other outcomes).

## `Quickshell.Services.Greetd` — `Greetd` singleton

Used by `greeter/GreeterWindow.qml` to drive greetd's login flow without hand-rolling the greetd IPC wire protocol:

- `Greetd.available` — whether a real greetd socket is present (false when running the greeter standalone outside greetd, e.g. via `qs -p greeter` for dev — this repo falls back to a `greetdMock` object in that case, see `GreeterWindow.qml`).
- `Greetd.createSession(username)` — begin a login attempt.
- `Greetd.respond(text)` — answer an auth prompt (password).
- `Greetd.launch(command: array, env: array, foo: bool)` — launch the session command once auth succeeds (this repo calls `window.backend.launch(window.sessionCommand, [], true)` — check current call site for the exact 3rd-arg meaning before relying on it, it wasn't self-documenting from the call alone).
- `Greetd.cancelSession()` — abort.
- Signals (via `Connections { target: Greetd }`, since these aren't plain property-changed signals): `authMessage(message, error, responseRequired)`, `authFailure(message)`, `error(message)`, `readyToLaunch()`.
- **Known quirk documented in this repo** (`GreeterWindow.qml` comment): Quickshell's `Greetd` singleton reacts to every `auth_error` by auto-sending a follow-up `cancel_session`, which races with greetd's worker teardown and often surfaces as a generic `onError` with an "unable to send message" description — that's normal noise after a wrong password, not a real dropped connection. Don't treat every `onError` as fatal.

## Other services imported in this repo (usage is straightforward property/signal reads — check the importing file directly rather than assuming API shape beyond what's listed)

- `Quickshell.Services.Mpris` — media player control, wrapped by this repo's own `shell/services/Mpris.qml` singleton.
- `Quickshell.Services.Notifications` — backs `shell/notifications/NotificationService.qml`.
- `Quickshell.Services.Pipewire` — volume/audio, feeds the OSD.
- `Quickshell.Services.UPower` — battery info, feeds `BatteryWidget`.
- `Quickshell.Services.SystemTray` — tray icons.
- `Quickshell.Networking` — NetworkManager wrapper.
- `Quickshell.Bluetooth` — BlueZ wrapper.
- `Quickshell.Widgets` — reusable Quickshell-provided QML components (not this repo's own widget files).

For any of these, `grep -rn "import Quickshell.Services.<Name>" shell/ common/` to find the actual usage site before writing new code against them — property names below the ones already covered above haven't been hand-verified here.

## `pragma Singleton`

Singletons in this repo live in `shell/services/`, `shell/wallpaper/`, `common/theme/`, `common/osd/`, `common/power/` (11 files total as of this writing — `grep -rl "pragma Singleton" shell/ common/` for the current list). Widgets read them directly (`Theme.textPrimary`, `Niri.workspaces`, `OSDController.showVolume`) rather than receiving props — standard Quickshell singleton pattern, not something specific to this repo.

## When this runs out

For anything not covered above — a new `Quickshell.Services.*` module, a property/signal this file doesn't mention, or if `quickshell --version` no longer prints `0.3.0` — don't guess. Fetch the live docs before writing the code:

- Type/module index: https://quickshell.org/docs/v0.3.0/types/Quickshell/ (swap `v0.3.0` for the installed version if it's moved on — check the version dropdown on that page).
- Guides (config root, QML language primer, FAQ): https://quickshell.org/docs/guide/introduction/

Update this file with what you learn if it's something this repo will keep using.
