import QtQuick
import qs.services
import qs.common.theme
import qs.common.widgets

IconTextBarPill {
  icon: "󰔏"
  iconColor: Theme.accentRed
  label: SystemInfo.temperature

  Accessible.role: Accessible.Button
  Accessible.name: "Temperature: " + SystemInfo.temperature

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Niri.openFloatingTui("btop")
  }
}
