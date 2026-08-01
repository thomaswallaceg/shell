import QtQuick
import qs.common.theme

// The common case: a BarPill showing an icon and/or a label side by side.
// Used by the simple status indicators (CPU, temperature, network, battery,
// volume, brightness). Anything declared as a child when instantiating this
// (e.g. a MouseArea) lands directly on the pill's Rectangle, so it can span
// the whole pill for click/wheel handling without affecting the icon/label
// layout.
BarPill {
  id: pill

  property string icon: ""
  // Optional glyph immediately after `icon` (e.g. battery-care shield).
  property string iconBadge: ""
  property int iconBadgePixelSize: ThemeEngine.fontSizeSm
  property string label: ""
  property string trailingIcon: ""
  property color iconColor: Theme.accentPrimary
  property color iconBadgeColor: iconColor
  property color trailingIconColor: iconColor
  property color textColor: Theme.textPrimary

  implicitWidth: content.width + 12

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 6

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      visible: pill.icon !== "" || pill.iconBadge !== ""

      Text {
        id: mainIcon
        anchors.verticalCenter: parent.verticalCenter
        visible: pill.icon !== ""
        text: pill.icon
        color: pill.iconColor
        font.pixelSize: ThemeEngine.fontSizeIcon
        font.family: ThemeEngine.fontFamily
      }
      // Match the main icon's line box so a smaller badge sits on its midline.
      Item {
        visible: pill.iconBadge !== ""
        width: badgeText.implicitWidth
        height: mainIcon.visible ? mainIcon.height : badgeText.implicitHeight

        Text {
          id: badgeText
          anchors.centerIn: parent
          text: pill.iconBadge
          color: pill.iconBadgeColor
          font.pixelSize: pill.iconBadgePixelSize
          font.family: ThemeEngine.fontFamily
        }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: pill.label !== ""
      text: pill.label
      color: pill.textColor
      font.pixelSize: ThemeEngine.fontSizeLg
      font.family: ThemeEngine.fontFamily
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: pill.trailingIcon !== ""
      text: pill.trailingIcon
      color: pill.trailingIconColor
      font.pixelSize: ThemeEngine.fontSizeIcon
      font.family: ThemeEngine.fontFamily
    }
  }
}
