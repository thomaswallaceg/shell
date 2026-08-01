import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// niri leaves focus on the floating TUI when clicking empty desktop space;
// this Bottom-layer catcher (below toplevels) closes it instead. Only mapped
// while a widget TUI is open so it doesn't steal empty-space input otherwise.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      visible: Niri.tuiWindowIds.length > 0
      color: "transparent"
      focusable: false

      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell/tui-dismiss"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      MouseArea {
        anchors.fill: parent
        onPressed: Niri.closeUnfocusedTuiWindows(null)
      }
    }
  }
}
