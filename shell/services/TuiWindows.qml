pragma Singleton

import Quickshell
import QtQuick
import qs.services

// The floating terminals bar widgets open for TUI tools (btop, wiremix, …):
// one at a time, closed again as soon as focus moves elsewhere. The window
// rule that actually floats them matches `windowTitle` below and lives in the
// niri config repo. Compositor access goes through Niri.qml.
Singleton {
  id: root

  property string terminal: "alacritty"
  readonly property string windowTitle: "quickshell-tui-widget"
  property var ids: []

  function open(command) {
    root.closeAll();
    Niri.dispatch(["spawn", "--", root.terminal, "-t", root.windowTitle, "-e", ...command.split(" ")]);
  }

  function closeAll() { root.closeOthers(null) }

  function closeOthers(focusedId) {
    for (const id of root.ids) {
      if (id !== focusedId)
        Niri.dispatch(["close-window", "--id", String(id)]);
    }
  }

  Connections {
    target: Niri

    function onIpcEvent(type, payload) {
      switch (type) {
        case "WindowsChanged": {
          const open = [];
          for (const win of payload?.windows ?? []) {
            if (win?.title === root.windowTitle)
              open.push(win.id);
          }
          root.ids = open;
          break;
        }
        case "WindowFocusChanged":
          root.closeOthers(payload?.id ?? null);
          break;
        case "WindowOpenedOrChanged": {
          const win = payload?.window;
          if (win?.title === root.windowTitle && !root.ids.includes(win.id))
            root.ids = root.ids.concat([win.id]);
          // niri skips WindowFocusChanged when a newly spawned window takes focus.
          if (win?.is_focused)
            root.closeOthers(win.title === root.windowTitle ? win.id : null);
          break;
        }
        case "WindowClosed":
          root.ids = root.ids.filter(id => id !== payload?.id);
          break;
      }
    }
  }
}
