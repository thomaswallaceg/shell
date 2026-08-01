import QtQuick
import qs.services
import qs.common.theme
import qs.common.widgets

IconTextBarPill {
  icon: "󰻠"
  iconColor: Theme.accentOrange
  label: SystemInfo.cpuUsage

  Accessible.role: Accessible.Button
  Accessible.name: "CPU: " + SystemInfo.cpuUsage

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Niri.openFloatingTui("btop")
  }
}
