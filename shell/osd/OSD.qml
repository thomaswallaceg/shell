import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../common/osd"

Scope {
  id: root

  // Ensure the singleton is instantiated even before the first volume change.
  readonly property var _osd: OSDController

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      // Same monitor as notifications — the smallest-resolution screen when
      // there's more than one, otherwise the only one there is.
      visible: (OSDController.showVolume || OSDController.showBrightness) && modelData === Displays.smallestScreen
      focusable: false
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell-osd"

      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      // Anchored only to the bottom: layer-shell centers a surface along any
      // axis it isn't anchored on, so leaving left/right unset centers it
      // horizontally.
      anchors {
        bottom: true
      }
      margins.bottom: 40

      implicitWidth: hud.implicitWidth
      implicitHeight: hud.implicitHeight

      OSDHud {
        id: hud
        anchors.fill: parent
      }
    }
  }
}
