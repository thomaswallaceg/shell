pragma Singleton

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import qs.services

// Idle-triggered lock / display power-off / suspend (ext-idle-notify-v1), with
// timeouts following UPower.onBattery live. Locking before a suspend this
// didn't trigger (lid close, `systemctl suspend`, low battery) is
// SleepWatcher.qml's job.
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
