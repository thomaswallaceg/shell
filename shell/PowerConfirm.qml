import Quickshell
import Quickshell.Wayland
import QtQuick
import "common/power"

// Session-layer confirm overlay. Lockscreen/greeter embed PowerConfirmDialog
// on their own surfaces instead — layer-shell is blanked while locked.
Scope {
  readonly property var _power: PowerController

  PanelWindow {
    visible: PowerController.confirmOpen
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-power-confirm"

    exclusionMode: ExclusionMode.Ignore

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    PowerConfirmDialog {
      anchors.fill: parent
    }
  }
}
