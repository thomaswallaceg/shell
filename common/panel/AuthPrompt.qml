import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.common.theme

// Shared clock + auth card UI for anything that needs a "type your
// credentials" screen (greeter/GreeterWindow.qml, shell/lockscreen/). Purely
// presentational — callers own the actual auth backend/state machine and
// just drive these properties/signals.
Column {
    id: root

    property string title: ""
    // Optional second line under the title, for callers with something longer
    // to say than a username (the polkit agent's action description). Kept
    // out of the bold title so the card doesn't read as one wall of text.
    property string subtitle: ""
    property string placeholder: ""
    property string accessibleName: placeholder
    property int echoMode: TextInput.Normal
    property bool waiting: false
    property string helpText: ""
    property string helpTextStatus: "normal" // normal | error
    property var keyHints: []
    // Optional account line above the input, for callers whose backend can
    // authenticate as more than one user (polkit hands the agent every admin
    // it would accept). Display names only — the caller maps the index back to
    // its own objects — and the line is hidden entirely when empty.
    property var identityNames: []
    property int selectedIdentityIndex: -1

    signal activated(string text, int modifiers)
    signal textEdited(string text)
    // The input consumes Escape and re-emits it (see PanelSearchInput), so
    // callers that can be dismissed listen here. The lockscreen deliberately
    // doesn't: there's no way out of it but a successful authentication.
    signal cancelled()
    signal identitySelected(int index)

    function clear() {
        inputField.clear();
    }

    function focusInput() {
        inputField.focusInput();
    }

    function cycleIdentity(direction) {
        const count = root.identityNames.length;
        if (count < 2)
            return;
        const from = root.selectedIdentityIndex < 0 ? 0 : root.selectedIdentityIndex;
        root.identitySelected((from + direction + count) % count);
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
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.textSecondary
                font.pixelSize: ThemeEngine.fontSizeSm
                font.family: ThemeEngine.fontFamily
                horizontalAlignment: Text.AlignHCenter
                // Capped so a pathological action description can't push the
                // input field off screen.
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // Who is being authenticated, centred over the field. Callers
            // with a single account (the lockscreen, the greeter) pass none
            // and the line disappears, leaving the card as it was before this
            // existed. The arrow is the only sign that there are others, and
            // it hangs off the side so the name stays centred on the card
            // whether or not it's there.
            Item {
                id: identityRow
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: root.identityNames.length > 0
                implicitHeight: identityLabel.implicitHeight

                Text {
                    id: identityLabel
                    anchors.centerIn: parent
                    // A fixed cap rather than one off the card's width: the
                    // card sizes itself from this row, so measuring it here
                    // would be a binding loop.
                    width: Math.min(implicitWidth, 220)
                    text: root.selectedIdentityIndex >= 0 && root.selectedIdentityIndex < root.identityNames.length
                        ? root.identityNames[root.selectedIdentityIndex]
                        : ""
                    color: root.identityNames.length > 1 ? Theme.accentPrimary : Theme.textSecondary
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: ThemeEngine.fontSizeSm
                    font.family: ThemeEngine.fontFamily

                    // Same thing Tab does, for whoever reaches for the mouse.
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.identityNames.length > 1 && !root.waiting
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleIdentity(1)
                    }
                }

                Text {
                    anchors.left: identityLabel.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: identityLabel.verticalCenter
                    visible: root.identityNames.length > 1
                    text: "↑↓"
                    color: Theme.textMuted
                    font.pixelSize: ThemeEngine.fontSizeSm
                    font.family: ThemeEngine.fontFamily

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.waiting
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleIdentity(1)
                    }
                }
            }

            PanelSearchInput {
                id: inputField
                // The account line already stands off the subtitle above it.
                Layout.topMargin: identityRow.visible ? 0 : 6
                enabled: !root.waiting
                opacity: enabled ? 1 : 0.5
                busy: root.waiting
                placeholder: root.placeholder
                accessibleName: root.accessibleName
                echoMode: root.echoMode
                selectByMouse: true
                onActivated: modifiers => root.activated(inputField.text, modifiers)
                onTextEdited: text => root.textEdited(text)
                onEscapePressed: root.cancelled()

                // The input holds the keyboard the whole time, so Tab/Backtab
                // (and Up/Down) walk the accounts from here; without acceptTab
                // the input swallows Tab as focus navigation.
                acceptTab: root.identityNames.length > 1
                onNavigate: direction => root.cycleIdentity(direction)

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
