import Quickshell
import Quickshell.Services.Greetd
import QtQuick
import QtQuick.Layouts
import "."
import "common/theme-switcher"
import "common/panel"

// Fullscreen login window. Meant to run standalone inside a minimal kiosk
// compositor (cage) launched by greetd — see README.md for the greetd/cage
// setup. Not wired into the main shell.qml; this is its own Quickshell config,
// sharing theme-switcher/ and a couple of panel UI atoms with the main shell
// via a single symlink into ../common/ (see AGENTS.md for why plain imports
// can't reach outside this directory).
FloatingWindow {
    id: window

    property var sessionCommand: ["niri-session"]

    implicitWidth: screen ? screen.width : 1280
    implicitHeight: screen ? screen.height : 720
    visible: true
    color: Theme.bgBase

    readonly property var screens: Quickshell.screens
    readonly property var mainScreen: {
        if (!screens || screens.length === 0)
            return null;
        let largest = screens[0];
        for (let i = 1; i < screens.length; i++) {
            if (screens[i].width * screens[i].height > largest.width * largest.height)
                largest = screens[i];
        }
        return largest;
    }
    readonly property int originX: screens && screens.length > 0 ? Math.min(...screens.map(s => s.x)) : 0
    readonly property int originY: screens && screens.length > 0 ? Math.min(...screens.map(s => s.y)) : 0
    readonly property real canvasWidth: screens && screens.length > 0 ? Math.max(...screens.map(s => s.x + s.width)) - originX : 0
    readonly property real canvasHeight: screens && screens.length > 0 ? Math.max(...screens.map(s => s.y + s.height)) - originY : 0

    readonly property bool spansCanvas: canvasWidth > 0 && window.width >= canvasWidth - 1 && window.height >= canvasHeight - 1

    property var activeScreen: mainScreen
    // Guards against the pointer's very first position update. Without this the UI could start
    // on whatever screen the mouse happens to be in when cage starts instead of the main screen.
    property bool pointerTrackingArmed: false

    HoverHandler {
        id: pointerTracker

        onPointChanged: {
            if (!window.pointerTrackingArmed) {
                window.pointerTrackingArmed = true;
                return;
            }
            if (!window.spansCanvas || !window.screens || window.screens.length <= 1)
                return;
            const gx = point.position.x + window.originX;
            const gy = point.position.y + window.originY;
            for (let i = 0; i < window.screens.length; i++) {
                const s = window.screens[i];
                if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height) {
                    if (s !== window.activeScreen)
                        window.activeScreen = s;
                    break;
                }
            }
        }
    }

    property string stage: "username" // username | password
    property bool waiting: false
    property string username: ""
    property string passwordMessage: ""
    property string helpText: ""
    property string helpTextStatus: "normal" // normal | error

    readonly property QtObject backend: Greetd.available ? Greetd : greetdMock

    GreetdMock {
        id: greetdMock
    }

    function submitUsername(text) {
        const trimmed = text.trim();
        if (!trimmed)
            return;
        window.username = trimmed;
        window.helpText = "";
        window.helpTextStatus = "normal";
        window.waiting = true;
        window.backend.createSession(trimmed);
    }

    function submitPassword(text) {
        window.helpText = "";
        window.helpTextStatus = "normal";
        window.waiting = true;
        window.backend.respond(text);
    }

    onStageChanged: inputField.clear();

    Connections {
        target: greetdMock

        function onMockLaunched() {
            window.stage = "username";
            window.waiting = false;
            window.username = "";
        }
    }

    Connections {
        target: window.backend

        // Only password auth is handled here — any responseRequired prompt is
        // assumed to be asking for the password and always masked, rather than
        // branching on echoResponse to support other PAM prompt types.
        function onAuthMessage(message, error, responseRequired) {
            if (responseRequired) {
                window.passwordMessage = message;
                window.stage = "password";
                window.waiting = false;
            } else {
                window.helpText = message;
                window.helpTextStatus = error ? "error" : "normal";
            }
        }

        function onAuthFailure(message) {
            window.helpText = "Wrong username or password";
            window.helpTextStatus = "error";
            window.stage = "username";
            window.waiting = false;
            window.username = "";
        }

        function onError(message) {
            // Quickshell's Greetd singleton reacts to every auth_error (wrong
            // password) by sending its own follow-up cancel_session — see
            // GreetdConnection::onSocketReady in Quickshell's source. That
            // races with greetd tearing down the just-failed PAM session
            // worker and greetd frequently reports the teardown race back as
            // a generic error whose description is an internal "unable to
            // send message: ..." (from greetd's own worker IPC, not our
            // connection to it — this arrives as a normal parsed IPC
            // response, so the socket to greetd is demonstrably still up).
            // It's not a real dropped connection, just noise that follows
            // almost every wrong-password attempt, so it shouldn't override
            // the real "Wrong username or password" onAuthFailure already
            // showed for that same attempt.
            if (message.indexOf("unable to send message") !== -1)
                return;
            window.helpText = message;
            window.helpTextStatus = "error";
            window.stage = "username";
            window.waiting = false;
        }

        function onReadyToLaunch() {
            window.backend.launch(window.sessionCommand, [], true);
        }
    }

    Component.onCompleted: {
        inputField.focusInput();
    }

    Item {
        x: window.spansCanvas && window.activeScreen ? window.activeScreen.x - window.originX : 0
        y: window.spansCanvas && window.activeScreen ? window.activeScreen.y - window.originY : 0
        width: window.spansCanvas && window.activeScreen ? window.activeScreen.width : parent.width
        height: window.spansCanvas && window.activeScreen ? window.activeScreen.height : parent.height

        Column {
            anchors.centerIn: parent
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
                        text: window.stage === "password" ? window.username : "Sign in"
                        color: Theme.textPrimary
                        font.pixelSize: ThemeEngine.fontSizeLg
                        font.family: ThemeEngine.fontFamily
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PanelSearchInput {
                        id: inputField
                        Layout.topMargin: 6
                        enabled: !window.waiting
                        opacity: enabled ? 1 : 0.5
                        busy: window.waiting
                        placeholder: window.stage === "password" ? window.passwordMessage : "Username"
                        accessibleName: window.stage === "password" ? window.passwordMessage : "Username"
                        echoMode: window.stage === "password" ? TextInput.Password : TextInput.Normal
                        selectByMouse: true
                        onActivated: window.stage === "password" ? submitPassword(inputField.text) : submitUsername(inputField.text)

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: messageMetrics.height
                        text: window.helpText || (window.waiting ? "Authenticating…" : "")
                        color: window.helpTextStatus === "error" ? Theme.accentRed : Theme.textMuted
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
                hints: [{ key: "⏎", label: window.stage === "password" ? "continue" : "next" }]
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(480, parent.width - 48)
            visible: !Greetd.available
            text: "No greetd socket found — running in dev mode (fake auth, see GreetdMock.qml)."
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            font.pixelSize: ThemeEngine.fontSizeSm
            font.family: ThemeEngine.fontFamily
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
