import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../common/widgets"

// There's an issue where some tray icons don't display correctly:
// https://github.com/quickshell-mirror/quickshell/issues/26
// https://github.com/quickshell-mirror/quickshell/pull/777
BarPill {
  id: root

  readonly property bool hasItems: SystemTray.items.values.length > 0
  visible: hasItems
  implicitWidth: hasItems ? trayIcons.implicitWidth + 4 : 0

  RowLayout {
    id: trayIcons
    anchors.centerIn: parent
    spacing: 2

    Repeater {
      model: SystemTray.items

      MouseArea {
        id: trayDelegate
        required property SystemTrayItem modelData

        Accessible.role: Accessible.Button
        Accessible.name: modelData.tooltipTitle || modelData.title || "System tray item"

        Layout.preferredWidth: 24
        Layout.preferredHeight: 24

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            modelData.activate()
          } else if (mouse.button === Qt.RightButton) {
            if (modelData.hasMenu) menuAnchor.open()
          } else if (mouse.button === Qt.MiddleButton) {
            modelData.secondaryActivate()
          }
        }

        IconImage {
          anchors.centerIn: parent
          source: trayDelegate.modelData.icon
          implicitSize: 16
        }

        QsMenuAnchor {
          id: menuAnchor
          menu: trayDelegate.modelData.menu

          anchor.window: trayDelegate.QsWindow.window
          anchor.adjustment: PopupAdjustment.Flip
          anchor.onAnchoring: {
            const window = trayDelegate.QsWindow.window;
            const widgetRect = window.contentItem.mapFromItem(
              trayDelegate, 0, trayDelegate.height,
              trayDelegate.width, trayDelegate.height);
            menuAnchor.anchor.rect = widgetRect;
          }
        }
      }
    }
  }
}
