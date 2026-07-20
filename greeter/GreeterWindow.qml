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

    // Command greetd should start after a successful login. Override per-machine
    // if you don't launch niri directly (e.g. ["dbus-run-session", "niri"]).
    property var sessionCommand: ["niri-session"]

    implicitWidth: screen ? screen.width : 1280
    implicitHeight: screen ? screen.height : 720
    visible: true
    color: Theme.bgBase

    // Multi-monitor handling: cage (the kiosk compositor hosting this greeter)
    // has no wlr-layer-shell support, so unlike the main shell's per-screen
    // PanelWindows (Bar/OSD/NotificationPopup), we can't create one surface
    // per screen here — cage only speaks xdg_shell, and forcibly maximizes
    // that single toplevel across the bounding box of every connected output
    // in its default "extend" mode (see cage's wiki on multi-monitor
    // behavior). So instead: the whole window stays a flat Theme.bgBase
    // background (which is also what any non-main screen ends up showing),
    // and the actual login UI below is confined to the sub-rectangle
    // matching the largest connected screen, positioned at that screen's real
    // offset within the shared canvas.
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
    // Only apply the mainScreen offset math above when this window's actual
    // surface genuinely spans that full combined canvas (cage's real
    // behavior). Running this file windowed under a normal compositor for
    // quick iteration (`qs -p greeter`) gives it an ordinary small
    // FloatingWindow instead — without this check the UI would still be
    // placed at mainScreen's absolute canvas offset, landing outside the
    // window's actual visible area and looking like a blank window.
    readonly property bool spansCanvas: canvasWidth > 0 && window.width >= canvasWidth - 1 && window.height >= canvasHeight - 1

    property string stage: "username" // username | prompt | waiting
    property string username: ""
    property string promptMessage: ""
    property bool promptSecret: true
    property string statusMessage: ""
    property string errorMessage: ""

    // Which field was on screen right before entering "waiting" — kept
    // visible (just disabled) through the wait instead of swapping it out
    // for the "Authenticating…" subtitle, so the card doesn't visibly lose
    // and regain its input field for the brief gap between submitting the
    // username and getting the password prompt back.
    property string lastInputStage: "username"

    // Dev-mode-only messages (see devMock* timers below) tend to run longer
    // than anything real greetd/PAM ever puts in errorMessage/statusMessage,
    // and are only ever seen while testing this file windowed — so they get
    // their own slot outside the card entirely, rather than forcing the
    // in-card message line to reserve space for text that's rare in
    // practice.
    property string devBannerMessage: ""

    function submitUsername(text) {
        const trimmed = text.trim();
        if (!trimmed)
            return;
        window.username = trimmed;
        window.errorMessage = "";
        window.statusMessage = "";
        window.lastInputStage = "username";
        window.stage = "waiting";
        if (Greetd.available)
            Greetd.createSession(trimmed);
        else
            devMockPasswordPrompt.start();
    }

    function submitPrompt(text) {
        // Clear any leftover error/status from a previous attempt (e.g. a
        // prior wrong password) so it doesn't keep overriding the
        // "Authenticating…" text below while this new attempt is pending —
        // mirrors submitUsername's clearing above.
        window.errorMessage = "";
        window.statusMessage = "";
        window.lastInputStage = "prompt";
        window.stage = "waiting";
        if (Greetd.available)
            Greetd.respond(text);
        else if (text === "oops")
            // Dev-mode-only trigger for exercising the wrong-password path
            // (see devMockAuthFailure below) without a real greetd socket
            // to reject a real password against.
            devMockAuthFailure.start();
        else
            devMockSignedIn.start();
    }

    // Dev-only stand-ins for the real greetd handshake, so the login flow
    // can be exercised while testing this file windowed (`qs -p greeter`,
    // see README) without a real greetd socket to answer createSession/
    // respond. All gated behind !Greetd.available, which greetd itself
    // guarantees is only ever false when there's no real session backing
    // it — so these can't run during an actual login.
    Timer {
        id: devMockPasswordPrompt
        interval: 400
        onTriggered: {
            window.promptMessage = "Password";
            window.promptSecret = true;
            window.stage = "prompt";
        }
    }

    // Mirrors onAuthFailure below: normalized error message, then straight
    // back to the password prompt for the same username (real greetd
    // retries in place too, rather than bouncing back to the username
    // field) — type "oops" as the password to trigger this.
    Timer {
        id: devMockAuthFailure
        interval: 400
        onTriggered: {
            window.errorMessage = "Wrong username or password";
            window.statusMessage = "";
            window.stage = "waiting";
            devMockPasswordPrompt.start();
        }
    }

    Timer {
        id: devMockSignedIn
        interval: 400
        onTriggered: {
            window.devBannerMessage = "Signed in (dev mode — no real session launched)";
            window.stage = "username";
            window.username = "";
        }
    }

    onStageChanged: {
        if (stage === "prompt")
            promptField.focusInput();
        else if (stage === "username")
            usernameField.focusInput();
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                window.promptMessage = message;
                window.promptSecret = !echoResponse;
                window.stage = "prompt";
            } else if (error) {
                window.errorMessage = message;
            } else {
                window.statusMessage = message;
            }
        }

        function onAuthFailure(message) {
            // Show a normalized message rather than the raw PAM text —
            // what the backend reports for a plain wrong username/password
            // varies by PAM stack/config and isn't necessarily meaningful
            // to a user (e.g. some setups surface generic-sounding text
            // here rather than anything reading as "wrong password").
            window.errorMessage = "Wrong username or password";
            window.statusMessage = "";
            // Let the user retry the same username immediately rather than
            // bouncing back to the username field.
            window.stage = "waiting";
            Greetd.createSession(window.username);
        }

        function onError(message) {
            window.errorMessage = message;
            window.statusMessage = "";
            window.stage = "username";
        }

        function onReadyToLaunch() {
            Greetd.launch(window.sessionCommand, [], true);
        }
    }

    Component.onCompleted: {
        if (!Greetd.available)
            window.devBannerMessage = "No greetd socket found — running in dev mode (fake auth, see devMock* timers above).";
        usernameField.focusInput();
    }

    Item {
        // Confine the UI to the main screen's rectangle within the shared
        // window (see multi-monitor comment above); any other screen is left
        // showing plain Theme.bgBase from the root window background.
        x: window.spansCanvas && window.mainScreen ? window.mainScreen.x - window.originX : 0
        y: window.spansCanvas && window.mainScreen ? window.mainScreen.y - window.originY : 0
        width: window.spansCanvas && window.mainScreen ? window.mainScreen.width : parent.width
        height: window.spansCanvas && window.mainScreen ? window.mainScreen.height : parent.height

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
                height: cardLayout.implicitHeight + 32
                radius: 16
                color: Theme.bgSurface
                border.color: Theme.bgBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: window.stage === "prompt" ? window.username : "Sign in"
                        color: Theme.textPrimary
                        font.pixelSize: ThemeEngine.fontSizeLg
                        font.family: ThemeEngine.fontFamily
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PanelSearchInput {
                        id: usernameField
                        visible: window.stage === "username" || (window.stage === "waiting" && window.lastInputStage === "username")
                        enabled: window.stage !== "waiting"
                        opacity: enabled ? 1 : 0.5
                        placeholder: "Username"
                        accessibleName: "Username"
                        selectByMouse: true
                        onActivated: submitUsername(usernameField.text)

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    PanelSearchInput {
                        id: promptField
                        visible: window.stage === "prompt" || (window.stage === "waiting" && window.lastInputStage === "prompt")
                        enabled: window.stage !== "waiting"
                        opacity: enabled ? 1 : 0.5
                        placeholder: window.promptMessage
                        accessibleName: window.promptMessage
                        echoMode: window.promptSecret ? TextInput.Password : TextInput.Normal
                        selectByMouse: true
                        onActivated: submitPrompt(promptField.text)

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    // Fixed one-line-tall slot for the error/status/
                    // "Authenticating…" line, reserved regardless of
                    // whether a message is showing. At most one of these is
                    // ever relevant at a time (error takes priority since
                    // it's the most actionable, then a real status message,
                    // then the generic waiting indicator) — using a single
                    // always-present element rather than three separately-
                    // visible ones keeps the card (and the whole centered
                    // login layout below it) from resizing/jumping as
                    // stage/errorMessage/statusMessage change. Text that
                    // doesn't fit on one line elides rather than wrapping —
                    // real messages here (see onAuthFailure/onAuthMessage
                    // above) are kept short enough not to need it; anything
                    // longer belongs in devBannerMessage below instead.
                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: messageMetrics.height
                        text: window.errorMessage || window.statusMessage || (window.stage === "waiting" ? "Authenticating…" : "")
                        // No color Behavior here deliberately — animating
                        // the color while text changes instantly caused a
                        // brief mismatch (new text in the old color, or vice
                        // versa) as they fell out of sync for the duration
                        // of the animation.
                        color: window.errorMessage ? Theme.accentRed : Theme.textMuted
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
                hints: [{ key: "⏎", label: window.stage === "prompt" ? "continue" : "next" }]
            }
        }

        // Dev-mode-only banner (see devBannerMessage above) — anchored to
        // the bottom of the screen independently of the centered login
        // Column above, so it can wrap to multiple lines without shifting
        // the card's position, since it's rare enough not to warrant a
        // permanently-reserved slot inside it.
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(480, parent.width - 48)
            visible: !!window.devBannerMessage
            text: window.devBannerMessage
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            font.pixelSize: ThemeEngine.fontSizeSm
            font.family: ThemeEngine.fontFamily
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
