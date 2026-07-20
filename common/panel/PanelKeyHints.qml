import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

RowLayout {
    id: root

    // Each entry: { key: "↑↓", label: "navigate" }
    property var hints: []

    Layout.fillWidth: true
    spacing: 16

    Repeater {
        model: root.hints

        delegate: Row {
            required property string key
            required property string label

            spacing: 4

            Rectangle {
                width: keyLabel.width + 8
                height: 18
                radius: 4
                color: Theme.bgSurface

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    id: keyLabel
                    anchors.centerIn: parent
                    text: key
                    color: Theme.textMuted
                    font.pixelSize: ThemeEngine.fontSizeSm
                    font.family: ThemeEngine.fontFamily
                }
            }

            Text {
                text: label
                color: Theme.textMuted
                font.pixelSize: ThemeEngine.fontSizeSm
                font.family: ThemeEngine.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Item { Layout.fillWidth: true }
}
