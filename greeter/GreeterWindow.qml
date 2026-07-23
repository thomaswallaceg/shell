import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick
import "."
import "common/theme-switcher"
import "common/panel"
import "common/osd"
import "common/widgets"

// Fullscreen login window. Meant to run standalone inside a minimal kiosk
// compositor (cage) launched by greetd — see README.md for the greetd/cage
// setup. Not wired into the main shell.qml; this is its own Quickshell config,
// sharing theme-switcher/ and a couple of panel UI atoms with the main shell
// via a single symlink into ../common/ (see AGENTS.md for why plain imports
// can't reach outside this directory).
FloatingWindow {
    id: window

    property var sessionCommand: ["niri-session"]
    // Absolute path to this checkout's niri/config.kdl, passed as NIRI_CONFIG
    // so niri-session → niri.service uses it instead of ~/.config/niri.
    // Prefer greeter/niri-config.path (written by install.sh into the
    // /etc/quickshell deploy). shellPath("../niri/...") is only safe as a
    // fallback when the greeter itself is running from the repo — under
    // /etc/quickshell that path resolves to a non-existent sibling.
    readonly property string niriConfig: {
        const fromDeploy = niriConfigPathFile.text().trim();
        if (fromDeploy !== "")
            return fromDeploy;
        if (!Quickshell.shellDir.startsWith("/etc/"))
            return Quickshell.shellPath("../niri/config.kdl");
        return "";
    }

    FileView {
        id: niriConfigPathFile
        path: Quickshell.shellPath("niri-config.path")
    }

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

    onStageChanged: authPrompt.clear();

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
            const env = [];
            if (window.niriConfig !== "")
                env.push("NIRI_CONFIG=" + window.niriConfig);
            window.backend.launch(window.sessionCommand, env, true);
        }
    }

    Component.onCompleted: {
        authPrompt.focusInput();
    }

    Item {
        x: window.spansCanvas && window.activeScreen ? window.activeScreen.x - window.originX : 0
        y: window.spansCanvas && window.activeScreen ? window.activeScreen.y - window.originY : 0
        width: window.spansCanvas && window.activeScreen ? window.activeScreen.width : parent.width
        height: window.spansCanvas && window.activeScreen ? window.activeScreen.height : parent.height

        AuthPrompt {
            id: authPrompt
            anchors.centerIn: parent
            title: window.stage === "password" ? window.username : "Sign in"
            placeholder: window.stage === "password" ? window.passwordMessage : "Username"
            accessibleName: window.stage === "password" ? window.passwordMessage : "Username"
            echoMode: window.stage === "password" ? TextInput.Password : TextInput.Normal
            waiting: window.waiting
            helpText: window.helpText
            helpTextStatus: window.helpTextStatus
            keyHints: [{ key: "⏎", label: window.stage === "password" ? "continue" : "next" }]
            onActivated: text => window.stage === "password" ? submitPassword(text) : submitUsername(text)
        }

        // Same placement as the session bar's right section. Fullscreen host
        // so the in-surface power menu can paint below the pills.
        Item {
            id: topChrome
            anchors.fill: parent
            z: 10

            MouseArea {
                anchors.fill: parent
                enabled: powerWidget.menuOpen
                onClicked: powerWidget.closeMenu()
            }

            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Math.round((ThemeEngine.barHeight - 24) / 2)
                anchors.rightMargin: 10
                spacing: 8

                VolumeWidget {}
                PowerWidget {
                    id: powerWidget
                    showSessionActions: false
                    inlineMenu: true
                    inlineMenuHost: topChrome
                }
            }
        }

        // Same active-screen Item as the auth card, so the OSD follows it.
        OSDHud {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            visible: OSDController.showVolume || OSDController.showBrightness
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
