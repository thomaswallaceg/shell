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
    // False swaps the input out for a status line. For a backend whose current
    // step isn't a question — polkit sitting inside pam_fprintd, which asks
    // nothing until the reader matches or times out — a password box would
    // invite input PAM isn't listening for, so the card shows what it's
    // waiting on instead. Callers that always have a question leave this true.
    property bool inputVisible: true
    // Glyph shown in the input's place while `inputVisible` is false. What
    // the card is waiting for is said once, on the help line below, so this
    // carries no text of its own.
    property string statusIcon: ""
    property color statusIconColor: Theme.accentPrimary
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

    // The keyboard lives on whichever of the two the card is currently
    // showing, so callers can keep calling this across a phase change.
    function focusInput() {
        if (root.inputVisible)
            inputField.focusInput();
        else
            factorRow.forceActiveFocus();
    }

    function cycleIdentity(direction) {
        const count = root.identityNames.length;
        if (count < 2)
            return;
        const from = root.selectedIdentityIndex < 0 ? 0 : root.selectedIdentityIndex;
        root.identitySelected((from + direction + count) % count);
    }

    // A disabled item can't hold active focus, so the input drops it the
    // moment `waiting` goes true and never gets it back on its own — leaving
    // the card enabled but dead to the keyboard once the attempt finishes.
    // The lockscreen only avoided this because its clear() re-focuses; a
    // caller with nothing to clear (polkit falling through to its password
    // prompt) needs the focus handed back explicitly.
    onWaitingChanged: if (!waiting && root.visible) focusInput()
    // Same handover the other way: neither half can hold focus while hidden,
    // so the phase change has to pass it along.
    onInputVisibleChanged: if (root.visible) focusInput()

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
                visible: root.inputVisible
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

            // Stands in for the input on a step that isn't asking anything.
            // It holds the keyboard itself — a hidden item can't — so Escape
            // and the account keys keep working with no field on the card.
            // Matches the input's height so the card doesn't resize when the
            // two swap.
            FocusScope {
                id: factorRow
                visible: !root.inputVisible
                focus: !root.inputVisible
                Layout.fillWidth: true
                Layout.topMargin: identityRow.visible ? 0 : 6
                implicitHeight: 44

                Keys.onEscapePressed: root.cancelled()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        event.accepted = true;
                        root.cycleIdentity(-1);
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        root.cycleIdentity(1);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.statusIcon
                    color: root.statusIconColor
                    font.pixelSize: Math.round(ThemeEngine.fontSizeIcon * 1.4)
                    font.family: ThemeEngine.fontFamily

                    // Breathes, so the card still reads as waiting on you
                    // now that there's no spinner to say so.
                    SequentialAnimation on opacity {
                        running: factorRow.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                    }
                }
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
