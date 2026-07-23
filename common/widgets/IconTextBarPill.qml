import QtQuick
import "../theme-switcher"

// The common case: a BarPill showing an icon and/or a label side by side.
// Used by the simple status indicators (CPU, temperature, network, battery,
// volume, brightness). Anything declared as a child when instantiating this
// (e.g. a MouseArea) lands directly on the pill's Rectangle, so it can span
// the whole pill for click/wheel handling without affecting the icon/label
// layout.
BarPill {
  id: pill

  property string icon: ""
  property string label: ""
  property color iconColor: Theme.accentPrimary
  property color textColor: Theme.textPrimary

  implicitWidth: content.width + 12

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 6

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: pill.icon !== ""
      text: pill.icon
      color: pill.iconColor
      font.pixelSize: ThemeEngine.fontSizeIcon
      font.family: ThemeEngine.fontFamily
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: pill.label !== ""
      text: pill.label
      color: pill.textColor
      font.pixelSize: ThemeEngine.fontSizeLg
      font.family: ThemeEngine.fontFamily
    }
  }
}
