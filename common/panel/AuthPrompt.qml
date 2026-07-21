import Quickshell
import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

// Shared clock + auth card UI for anything that needs a "type your
// credentials" screen (greeter/GreeterWindow.qml, shell/lockscreen/). Purely
// presentational — callers own the actual auth backend/state machine and
// just drive these properties/signals.
Column {
    id: root

    property string title: ""
    property string placeholder: ""
    property string accessibleName: placeholder
    property int echoMode: TextInput.Normal
    property bool waiting: false
    property string helpText: ""
    property string helpTextStatus: "normal" // normal | error
    property var keyHints: []

    signal activated(string text, int modifiers)
    signal textEdited(string text)

    function clear() {
        inputField.clear();
    }

    function focusInput() {
        inputField.focusInput();
    }

    spacing: 24

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Theme.textPrimary
            font.pixelSize: 56
            font.family: ThemeEngine.fontFamily
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "ddd MMM d")
            color: Theme.textSecondary
            font.pixelSize: ThemeEngine.fontSizeLg
            font.family: ThemeEngine.fontFamily
        }

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }
    }

    Rectangle {
        id: card
        width: 360
        anchors.horizontalCenter: parent.horizontalCenter
        height: cardLayout.implicitHeight + 24
        radius: 16
        color: Theme.bgSurface
        border.color: Theme.bgBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.textPrimary
                font.pixelSize: ThemeEngine.fontSizeLg
                font.family: ThemeEngine.fontFamily
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            PanelSearchInput {
                id: inputField
                Layout.topMargin: 6
                enabled: !root.waiting
                opacity: enabled ? 1 : 0.5
                busy: root.waiting
                placeholder: root.placeholder
                accessibleName: root.accessibleName
                echoMode: root.echoMode
                selectByMouse: true
                onActivated: modifiers => root.activated(inputField.text, modifiers)
                onTextEdited: text => root.textEdited(text)

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: messageMetrics.height
                text: root.helpText || (root.waiting ? "Authenticating…" : "")
                color: root.helpTextStatus === "error" ? Theme.accentRed : Theme.textMuted
                elide: Text.ElideRight
                font.pixelSize: ThemeEngine.fontSizeSm
                font.family: ThemeEngine.fontFamily
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                FontMetrics {
                    id: messageMetrics
                    font.family: ThemeEngine.fontFamily
                    font.pixelSize: ThemeEngine.fontSizeSm
                }
            }
        }
    }

    PanelKeyHints {
        anchors.horizontalCenter: parent.horizontalCenter
        hints: root.keyHints
    }
}
