import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

Text {
    property bool animateColor: false

    color: Theme.textMuted
    font.pixelSize: ThemeEngine.fontSizeSm
    font.family: ThemeEngine.fontFamily
    Layout.leftMargin: 4

    Behavior on color {
        enabled: animateColor
        ColorAnimation { duration: 150 }
    }
}
