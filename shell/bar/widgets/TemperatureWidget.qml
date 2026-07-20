import QtQuick
import "../../services"
import "../../common/theme-switcher"

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
