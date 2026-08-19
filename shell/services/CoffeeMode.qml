pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// "Keep this machine awake" toggle — IdleManager.qml disables all of its
// idle-triggered lock/monitors-off/suspend behavior while this is on. Purely
// runtime state (not persisted across quickshell restarts): this is a "right
// now" override, not a saved preference.
Singleton {
  id: root

  property bool enabled: false

  function toggle() {
    enabled = !enabled;
  }

  IpcHandler {
    target: "coffee"

    function toggle(): void { root.toggle(); }
  }
}
