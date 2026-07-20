import QtQuick
import "../../services"
import "../../common/theme-switcher"

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
