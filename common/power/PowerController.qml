pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared power actions + logind inhibitor probe. Bar, launcher, lockscreen,
// and greeter all call request(); reboot/shutdown check systemd-inhibit first
// and only prompt when something is delaying shutdown.
Singleton {
  id: root

  property bool confirmOpen: false
  property bool checking: false
  property string pendingAction: ""
  property var inhibitors: []

  readonly property string pendingLabel: pendingAction === "reboot" ? "Restart" : "Shut Down"
  readonly property string pendingVerb: pendingAction === "reboot" ? "restart" : "shut down"

  function request(action) {
    if (action !== "reboot" && action !== "shutdown") {
      execute(action);
      return;
    }

    pendingAction = action;
    inhibitors = [];
    confirmOpen = false;
    checking = true;
    // Restart the process even if a previous probe is mid-flight.
    inhibitProc.running = false;
    inhibitProc.running = true;
  }

  function confirm() {
    const action = pendingAction;
    clearConfirm();
    if (action !== "")
      execute(action);
  }

  function cancel() {
    clearConfirm();
  }

  function clearConfirm() {
    confirmOpen = false;
    checking = false;
    pendingAction = "";
    inhibitors = [];
    inhibitProc.running = false;
  }

  function execute(action) {
    switch (action) {
      case "lock":
        Quickshell.execDetached(["qs", "ipc", "call", "lockscreen", "lock"]);
        break;
      case "suspend":
        Quickshell.execDetached(["systemctl", "suspend"]);
        break;
      case "reboot":
        Quickshell.execDetached(["systemctl", "reboot"]);
        break;
      case "shutdown":
        Quickshell.execDetached(["systemctl", "poweroff"]);
        break;
      case "logout":
        Quickshell.execDetached(["niri", "msg", "action", "quit"]);
        break;
    }
  }

  function parseInhibitors(text) {
    const trimmed = text.trim();
    if (trimmed === "" || trimmed === "null")
      return [];

    let parsed;
    try {
      parsed = JSON.parse(trimmed);
    } catch (e) {
      console.error("PowerController: failed to parse inhibitors:", e);
      return [];
    }

    const rows = Array.isArray(parsed) ? parsed : [];
    const out = [];
    for (const row of rows) {
      if (!row || typeof row !== "object")
        continue;
      const who = row.who ?? row.Who ?? "";
      const why = row.why ?? row.Why ?? "";
      const mode = row.mode ?? row.Mode ?? "";
      const comm = row.comm ?? row.COMM ?? "";
      if (who === "" && why === "" && comm === "")
        continue;
      out.push({ who: who, why: why, mode: mode, comm: comm });
    }
    return out;
  }

  Process {
    id: inhibitProc
    command: [
      "systemd-inhibit",
      "--list",
      "--json=short",
      "--what=shutdown",
      "--no-pager",
      "--no-legend"
    ]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.checking)
          return;

        const action = root.pendingAction;
        const list = root.parseInhibitors(text);
        root.checking = false;

        if (list.length === 0) {
          root.clearConfirm();
          root.execute(action);
          return;
        }

        root.inhibitors = list;
        root.confirmOpen = true;
      }
    }
  }
}
