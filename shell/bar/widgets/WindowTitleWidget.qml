import QtQuick
import qs.services
import qs.common.theme

Item {
  id: root

  Text {
    Accessible.role: Accessible.StaticText
    Accessible.name: "Active window: " + text
    text: Niri.activeWindowTitle
    color: Theme.textPrimary
    font.pixelSize: ThemeEngine.fontSizeLg
    font.family: ThemeEngine.fontFamily
    elide: Text.ElideRight
    width: Math.min(implicitWidth, parent.width)
    anchors.centerIn: parent
  }
}
