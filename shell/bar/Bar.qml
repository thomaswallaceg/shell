import Quickshell
import QtQuick
import Quickshell.Io
import qs.services
import qs.common.theme
import qs.bar.widgets

Scope {
  id: root
  property bool barVisible: true

  TuiDismiss {}

  // Typography and bar height live in ThemeEngine — widgets use ThemeEngine.* directly.

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barVisible = !root.barVisible; }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData
      // Shown on the smallest screen — usually the one least likely to be a
      // primary display. Screen topology lives in Displays.qml (shared with
      // notifications and any other monitor-aware module).
      readonly property bool isTargetScreen: modelData === Displays.smallestScreen

      visible: root.barVisible && isTargetScreen
      exclusiveZone: ThemeEngine.barHeight

      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: ThemeEngine.barHeight
      color: "transparent"

      Rectangle {
        id: barSurface
        anchors.left: parent.left
        anchors.right: parent.right
        height: ThemeEngine.barHeight
        color: Theme.bgBase

        Item {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10

          Row {
            id: leftSection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            CpuWidget {}
            TemperatureWidget {}
            WorkspacesWidget {}
            SystemTrayWidget {}
            NowPlayingWidget {}
          }

          Item {
            anchors.centerIn: parent
            height: parent.height
            width: Math.max(0, parent.width - 2 * Math.max(leftSection.width, rightSection.width) - 32)

            WindowTitleWidget { anchors.fill: parent }
          }

          Row {
            id: rightSection
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            CoffeeModeWidget {}
            VolumeWidget {}
            BrightnessWidget {}
            NetworkWidget {}
            BluetoothWidget {}
            BatteryWidget {}
            TimeWidget {}
            PowerWidget {}
          }
        }

        // Layer-shell panels don't take window focus, so bar clicks alone
        // wouldn't fire the TUI close-on-focus-loss path.
        MouseArea {
          anchors.fill: parent
          propagateComposedEvents: true
          onPressed: mouse => {
            TuiWindows.closeAll();
            mouse.accepted = false;
          }
        }
      }
    }
  }
}
