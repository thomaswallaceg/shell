import QtQuick
import qs.common.theme
import qs.common.widgets
import qs.services

// Status pill shown only while CoffeeMode is on (see CoffeeMode.qml) —
// click to turn it back off, same as toggling it again from the launcher.
IconTextBarPill {
  id: root

  visible: CoffeeMode.enabled
  icon: "󰅶"
  iconColor: Theme.accentPrimary

  Accessible.role: Accessible.Button
  Accessible.name: "Coffee mode on — click to turn off"

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: CoffeeMode.toggle()
  }
}
