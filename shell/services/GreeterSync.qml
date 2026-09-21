pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.common.theme

// The launcher's "Sync greeter theme and font" action: copies this user's
// theme/font into the admin-owned /etc/thomas-shell/greeter.json that the
// greeter reads. Needs root, hence pkexec (see the polkit policy in polkit/).
Singleton {
  id: root

  // False on machines running a different display manager, where the action
  // would do nothing useful — the launcher hides it then. Checks that greetd
  // is running *and* that it's pointed at this repo's greeter.
  property bool available: false

  property string lastError: ""

  function sync() {
    if (syncProc.running)
      return;
    syncProc.running = true;
  }

  Process {
    running: true
    command: ["sh", "-c",
      'systemctl is-active --quiet greetd && readlink -f /etc/greetd/config.toml | grep -q "/thomas-shell/greeter/config.toml$"']
    onExited: exitCode => root.available = exitCode === 0
  }

  Process {
    id: syncProc
    command: ["pkexec", Quickshell.shellPath("scripts/sync-greeter-preferences.sh"),
      ThemeEngine.currentId, ThemeEngine.savedFontFamily]
    running: false

    // Without this the helper fails silently: a missing polkit agent, a
    // cancelled prompt or a rejected theme id all look like nothing happening.
    stderr: StdioCollector {
      onStreamFinished: root.lastError = text.trim()
    }

    onExited: exitCode => {
      if (exitCode === 0)
        return;
      console.warn("GreeterSync: sync failed (exit " + exitCode + ")",
        root.lastError !== "" ? "— " + root.lastError : "");
    }
  }
}
