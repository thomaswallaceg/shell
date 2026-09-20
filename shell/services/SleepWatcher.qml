pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Locks before the system sleeps and powers the monitors back on after it
// wakes — what the swayidle unit used to do. logind announces both with its
// PrepareForSleep signal (true before sleeping, false on resume); nothing in
// Quickshell wraps logind, so this watches `gdbus monitor` for it. Not
// `busctl monitor`: monitoring the system bus needs root, receiving its
// broadcast signals doesn't.
//
// The delay inhibitor is what makes the lock land *before* the machine
// suspends: logind holds the sleep until it's released (at most
// InhibitDelayMaxSec, 5s by default).
Singleton {
  id: root

  Process {
    id: inhibitor
    running: true
    command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Shell",
      "--why=Lock the session before sleep", "sleep", "infinity"]
  }

  // Blank first so the lockscreen doesn't flash on screen on the way down;
  // niri turns the monitors back on by itself on the next input, and resume
  // does it explicitly below.
  Process {
    id: monitorsOff
    command: Niri.actionCommand(["power-off-monitors"])
    onExited: lockProc.running = true
  }

  // Each step waits for the previous one to exit, so the order is guaranteed:
  // blank, lock, then release the inhibitor and let the machine sleep.
  Process {
    id: lockProc
    command: ["qs", "ipc", "call", "lockscreen", "lock"]
    onExited: inhibitor.running = false
  }

  Process {
    id: sleepSignals
    running: true
    command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
      "--object-path", "/org/freedesktop/login1"]
    // One line per signal, e.g.
    // `/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)`
    stdout: SplitParser {
      onRead: line => {
        if (line.includes("PrepareForSleep (true")) {
          monitorsOff.running = true;
        } else if (line.includes("PrepareForSleep (false")) {
          Niri.dispatch(["power-on-monitors"]);
          inhibitor.running = true;
        }
      }
    }
    onExited: restart.start()
  }

  // Via a timer so a gdbus that fails immediately can't spin.
  Timer {
    id: restart
    interval: 2000
    onTriggered: sleepSignals.running = true
  }
}
