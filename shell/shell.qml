//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Io
import QtQuick
import "bar"
import "panel"
import "notifications"
import "osd"
import "lockscreen"
import "common/power"

Scope {
  // Keep the singleton alive for bar/launcher power actions.
  readonly property var _power: PowerController

  ShellPanel {}
  Bar {}
  NotificationPopup {}
  OSD {}
  Lockscreen {}
  PowerConfirm {}
}
