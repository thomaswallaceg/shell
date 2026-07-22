import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

// Shared horizontal pill for the OSD — a rounded capsule with an icon glyph,
// a fill bar, and a percentage label, laid out left to right. Used for both
// volume and brightness; callers just supply the value/color/icon/label.
Rectangle {
  id: root

  property bool shown: false
  property string label: ""
  property real value: 0
  property color fillColor: Theme.accentPrimary
  property string icon: ""
  property string accessibleName: ""

  width: 300
  height: 50
  radius: height / 2
  color: Theme.bgBase
  border.color: Theme.bgBorder
  border.width: 1
  opacity: shown ? 1 : 0

  Behavior on opacity { NumberAnimation { duration: 150 } }

  Accessible.role: Accessible.ProgressBar
  Accessible.name: root.accessibleName

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    spacing: 12

    Text {
      text: root.icon
      color: root.fillColor
      font.pixelSize: ThemeEngine.fontSizeIcon
      font.family: ThemeEngine.fontFamily
      Layout.alignment: Qt.AlignVCenter
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      height: 8
      radius: 4
      color: Theme.bgSurface
      border.color: Theme.bgBorder
      border.width: 1
      clip: true

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2
        width: Math.max(0, (parent.width - 4) * Math.max(0, Math.min(1, root.value)))
        radius: 3
        color: root.fillColor

        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
      }
    }

    Text {
      text: root.label
      color: Theme.textSecondary
      font.pixelSize: ThemeEngine.fontSizeSm
      font.family: ThemeEngine.fontFamily
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: 40
      horizontalAlignment: Text.AlignRight
    }
  }
}
