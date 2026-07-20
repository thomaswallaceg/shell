import QtQuick
import "../common/theme-switcher"

Item {
    required property string section

    width: parent.width
    height: 28

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: section.toUpperCase()
        color: Theme.textMuted
        font.pixelSize: ThemeEngine.fontSizeSm
        font.family: ThemeEngine.fontFamily
        font.bold: true
        font.letterSpacing: 1.5

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
}
