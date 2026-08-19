pragma Singleton

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import qs.services

// Idle-triggered lock / display power-off / suspend, via Quickshell's own
// wrapper around the ext-idle-notify-v1 Wayland protocol — the same protocol
// swayidle uses, just without shelling out to it. Timeouts are a live
// binding against UPower.onBattery (aggressive on battery, relaxed on AC/
// desktops) rather than a value picked once at process start, so plugging in
// or unplugging takes effect immediately with no restart needed — unlike the
// old swayidle-wrapper.sh + swayidle-power-watch.sh pair this replaces.
//
// What this does NOT cover: locking before a suspend/lid-close that *this*
// timeout chain didn't trigger (e.g. logind's own HandleLidSwitch=suspend
// default), and turning monitors back on after resume. Those key off
// logind's PrepareForSleep DBus signal, which nothing in Quickshell wraps —
// systemd/swayidle.service still exists for exactly that, stripped down to
// just its `after-resume`/`before-sleep` hooks.
Singleton {
  id: root

  readonly property int lockTimeout: UPower.onBattery ? 300 : 900
  readonly property int monitorsOffTimeout: UPower.onBattery ? 330 : 960
  readonly property int suspendTimeout: UPower.onBattery ? 600 : 1800

  IdleMonitor {
    // CoffeeMode disables every stage below rather than just the suspend
    // one — no point locking or blanking the screen either while it's on.
    enabled: !CoffeeMode.enabled
    timeout: root.lockTimeout
    onIsIdleChanged: if (isIdle)
      Quickshell.execDetached(["qs", "ipc", "call", "lockscreen", "lock"])
  }

  IdleMonitor {
    enabled: !CoffeeMode.enabled
    timeout: root.monitorsOffTimeout
    onIsIdleChanged: if (isIdle)
      Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
  }

  IdleMonitor {
    enabled: !CoffeeMode.enabled
    timeout: root.suspendTimeout
    onIsIdleChanged: if (isIdle)
      Quickshell.execDetached(["systemctl", "suspend"])
  }
}
