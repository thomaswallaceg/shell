import QtQuick
import "../../services"
import "../../common/theme-switcher"

BarPill {
  id: pill

  implicitWidth: timeDate.width + 16

  Row {
    id: timeDate
    anchors.centerIn: parent
    spacing: 8

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.timeString
      color: Theme.textPrimary
      font.pixelSize: ThemeEngine.fontSizeLg
      font.family: ThemeEngine.fontFamily
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.dateString
      color: Theme.textSecondary
      font.pixelSize: ThemeEngine.fontSizeLg
      font.family: ThemeEngine.fontFamily
    }
  }

  Accessible.role: Accessible.Button
  Accessible.name: "Time and date: " + Time.timeString + ", " + Time.dateString

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Niri.openFloatingTui("minical")
  }
}
