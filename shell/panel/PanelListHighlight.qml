import QtQuick
import "../common/theme-switcher"

Rectangle {
    radius: 8
    color: Theme.bgSelected

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Rectangle {
        width: 3
        height: 24
        radius: 2
        color: Theme.accentPrimary
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
}
