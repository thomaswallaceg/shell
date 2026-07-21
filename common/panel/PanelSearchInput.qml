import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../theme-switcher"

Rectangle {
    id: root

    property alias text: searchField.text
    property string placeholder: "Search..."
    property string accessibleName: "Search"
    property bool selectByMouse: false
    property bool acceptTab: false
    property alias echoMode: searchField.echoMode
    // Small spinner on the right, for callers with an async operation tied
    // to this field's input (e.g. waiting on a search/auth response).
    property bool busy: false

    signal escapePressed()
    signal navigate(int direction)
    signal activated(int modifiers)
    signal textEdited(string text)

    Layout.fillWidth: true
    height: 44
    radius: 10
    color: Theme.bgSurface
    border.color: searchField.activeFocus ? Theme.accentPrimary : Theme.bgBorder
    border.width: 1

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    function focusInput() {
        searchField.forceActiveFocus();
    }

    function clear() {
        searchField.text = "";
        focusInput();
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        TextInput {
            id: searchField
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: ThemeEngine.fontSizeLg
            font.family: ThemeEngine.fontFamily
            clip: true
            selectByMouse: root.selectByMouse
            Accessible.role: Accessible.EditableText
            Accessible.name: root.accessibleName

            Text {
                anchors.fill: parent
                text: root.placeholder
                color: Theme.textMuted
                font: parent.font
                visible: !parent.text && !parent.activeFocus
                verticalAlignment: Text.AlignVCenter
            }

            onTextChanged: root.textEdited(text)

            Keys.onEscapePressed: root.escapePressed()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                    root.navigate(-1);
                } else if (event.key === Qt.Key_Down || (root.acceptTab && event.key === Qt.Key_Tab)) {
                    event.accepted = true;
                    root.navigate(1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    root.activated(event.modifiers);
                }
            }
        }

        Item {
            id: spinner
            visible: root.busy
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter

            Shape {
                anchors.fill: parent
                antialiasing: true
                // The default GeometryRenderer approximates curves with line
                // segments and relies on MSAA for smoothing, which still looks
                // chunky at this size for a small rotating arc. CurveRenderer
                // renders the arc analytically instead, so it stays smooth at
                // any size/rotation without needing multisampling.
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 2
                    strokeColor: Theme.textMuted
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: spinner.width / 2
                        centerY: spinner.height / 2
                        radiusX: spinner.width / 2 - 1
                        radiusY: spinner.height / 2 - 1
                        sweepAngle: 270
                    }
                }
            }

            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 800
            }
        }
    }
}
