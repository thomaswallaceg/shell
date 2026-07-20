pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Niri has no bundled Quickshell module (unlike Hyprland/i3), so this talks to
// niri's own JSON IPC directly: `niri msg --json ...` for one-shot queries, and
// a long-running `niri msg --json event-stream` for live updates. See:
// https://yalter.github.io/niri/niri_ipc/ (or `niri msg --help`)
Singleton {
  id: root

  // Array of { id, idx, output, focused, urgent, active }, sorted by output
  // then by idx — mirrors the shape the bar previously read off Hyprland.workspaces.
  property var workspaces: []
  property string activeWindowTitle: ""

  function refreshWorkspaces() { workspacesProc.running = true }
  function refreshActiveWindow() { activeWindowProc.running = true }

  property string terminal: "alacritty"
  readonly property string tuiWindowTitle: "quickshell-tui-widget"
  property var tuiWindowIds: []

  function openFloatingTui(command) {
    spawnProc.command = ["niri", "msg", "action", "spawn", "--", terminal, "-t", tuiWindowTitle, "-e", command];
    spawnProc.running = true;
  }

  function syncTuiWindows(windows) {
    const ids = [];
    for (const win of windows) {
      if (win?.title === tuiWindowTitle)
        ids.push(win.id);
    }
    tuiWindowIds = ids;
  }

  function closeUnfocusedTuiWindows(focusedId) {
    for (const id of tuiWindowIds) {
      if (id === focusedId)
        continue;
      Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(id)]);
    }
  }

  function removeTuiWindow(id) {
    tuiWindowIds = tuiWindowIds.filter(winId => winId !== id);
  }

  Process {
    id: spawnProc
    running: false
  }

  Process {
    id: workspacesProc
    command: ["niri", "msg", "--json", "workspaces"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const raw = JSON.parse(text)
          raw.sort((a, b) => (a.output || "").localeCompare(b.output || "") || a.idx - b.idx)
          root.workspaces = raw.map(w => ({
            id: w.id,
            idx: w.idx,
            output: w.output || "",
            focused: !!w.is_focused,
            urgent: !!w.is_urgent,
            active: !!w.is_active
          }))
        } catch (e) {
          console.error("Niri: failed to parse workspaces:", e)
        }
      }
    }
  }

  Process {
    id: activeWindowProc
    command: ["niri", "msg", "--json", "focused-window"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const raw = text.trim()
          const win = raw ? JSON.parse(raw) : null
          root.activeWindowTitle = (win && win.title) || ""
        } catch (e) {
          console.error("Niri: failed to parse focused-window:", e)
        }
      }
    }
  }

  // Long-running connection: rather than re-implement niri's full window/workspace
  // model locally, treat each event as a cheap "something changed, re-query" signal.
  Process {
    id: eventStream
    command: ["niri", "msg", "--json", "event-stream"]
    running: true

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        if (!data) return
        let event
        try {
          event = JSON.parse(data)
        } catch (e) {
          return
        }

        const type = Object.keys(event)[0]
        const payload = event[type]
        switch (type) {
          case "WorkspacesChanged":
          case "WorkspaceUrgencyChanged":
          case "WorkspaceActivated":
          case "WorkspaceActiveWindowChanged":
            root.refreshWorkspaces()
            break
          case "WindowsChanged":
            root.syncTuiWindows(payload?.windows ?? [])
            root.refreshActiveWindow()
            break
          case "WindowFocusChanged":
            root.closeUnfocusedTuiWindows(payload?.id ?? null)
            root.refreshActiveWindow()
            break
          case "WindowOpenedOrChanged":
            if (payload?.window?.title === root.tuiWindowTitle) {
              const id = payload.window.id;
              if (!root.tuiWindowIds.includes(id))
                root.tuiWindowIds = root.tuiWindowIds.concat([id]);
            }
            root.refreshActiveWindow()
            break
          case "WindowClosed":
            root.removeTuiWindow(payload?.id)
            root.refreshActiveWindow()
            break
        }
      }
    }
  }
}
