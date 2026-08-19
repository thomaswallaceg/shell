//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import QtQuick
import qs.bar
import qs.panel
import qs.notifications
import qs.osd
import qs.lockscreen
import qs.wallpaper
import qs.common.power
import qs.services

Scope {
  // Keep the singleton alive for bar/launcher power actions.
  readonly property var _power: PowerController
  // Keep the singleton alive so its IdleMonitors actually run — see
  // IdleManager.qml.
  readonly property var _idle: IdleManager
  // Keep the singleton alive so its IpcHandler responds to
  // `qs ipc call coffee toggle` even before the bar widget/launcher touch it.
  readonly property var _coffee: CoffeeMode

  Wallpaper {}
  ShellPanel {}
  Bar {}
  NotificationPopup {}
  OSD {}
  Lockscreen {}
  PowerConfirm {}
}
