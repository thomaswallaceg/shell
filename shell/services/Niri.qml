pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Compositor adapter: workspace/window state, niri actions, and the raw event
// stream. Niri has no bundled Quickshell module (unlike Hyprland/i3), so this
// is shaped like those — shell code reads state or calls dispatch() here
// instead of running `niri msg` itself. Anything policy-shaped (which windows
// to close, when to blank the screen) belongs in its caller, not here; see
// TuiWindows.qml. https://niri-wm.github.io/niri/niri_ipc/
Singleton {
  id: root

  // Array of { id, idx, output, focused, urgent, active }, sorted by output
  // then by idx — mirrors the shape the bar previously read off Hyprland.workspaces.
  property var workspaces: []
  property string activeWindowTitle: ""

  // Every event niri sends, forwarded as-is for callers that need more than
  // the state above.
  signal ipcEvent(string type, var payload)

  function refreshWorkspaces() { workspacesProc.running = true }
  function refreshActiveWindow() { activeWindowProc.running = true }

  // `niri msg action <args>`. actionCommand is for callers that need to run it
  // as their own Process — e.g. to wait for it to finish (SleepWatcher.qml).
  function actionCommand(args) { return ["niri", "msg", "action", ...args] }
  function dispatch(args) { Quickshell.execDetached(root.actionCommand(args)) }

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
          case "WindowFocusChanged":
          case "WindowOpenedOrChanged":
          case "WindowClosed":
            root.refreshActiveWindow()
            break
        }

        root.ipcEvent(type, payload)
      }
    }
  }
}
