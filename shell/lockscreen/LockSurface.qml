import Quickshell
import QtQuick
import "../common/theme-switcher"
import "../common/panel"
import "../common/osd"
import "../common/widgets"

// Per-screen lockscreen content, displayed inside each WlSessionLockSurface
// (see Lockscreen.qml). Same visual language as the greeter's AuthPrompt,
// but always password-only for the current user — no username stage, since
// the session is already known to belong to Quickshell.env("USER").
//
// Unlike the greeter (a single window spanning all outputs, since cage lacks
// per-output surfaces), WlSessionLock gives every screen its own real
// surface/instance of this component. To still mirror the greeter's
// "biggest screen first, then follow the mouse" behavior rather than
// showing the auth card on every screen at once, only the screen Lockscreen
// has picked as `active` actually shows/accepts input for it — others stay a
// plain themed background.
Rectangle {
    id: root

    required property LockContext context
    property bool active: true

    signal pointerMoved()

    // Guards against this surface's very first pointer report (compositors
    // report the pointer's current position as soon as a surface appears,
    // even without real movement) — without this the active screen could
    // flip away from the main screen right at lock time.
    property bool pointerTrackingArmed: false

    color: Theme.bgBase

    Behavior on color { ColorAnimation { duration: 150 } }

    HoverHandler {
        onPointChanged: {
            if (!root.pointerTrackingArmed) {
                root.pointerTrackingArmed = true;
                return;
            }
            root.pointerMoved();
        }
    }

    AuthPrompt {
        id: authPrompt
        anchors.centerIn: parent
        visible: root.active
        enabled: root.active
        title: Quickshell.env("USER")
        placeholder: "Password"
        accessibleName: "Password"
        echoMode: TextInput.Password
        waiting: root.context.unlockInProgress
        helpText: root.context.helpText
        helpTextStatus: root.context.helpTextStatus
        keyHints: [{ key: "⏎", label: "unlock" }]
        onActivated: text => {
            root.context.currentText = text;
            root.context.tryUnlock();
        }
    }

    // Fullscreen host so the in-surface power menu can paint below the pills
    // without being trapped in a barHeight-tall item. Above AuthPrompt so the
    // dropdown isn't covered by the card. PopupWindow can't map here
    // (ext_session_lock_v1 = one surface per output).
    Item {
        id: topChrome
        anchors.fill: parent
        visible: root.active
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

    // Layer-shell OSD is blanked while locked; render the same HUD here,
    // only on the screen that currently shows the auth card.
    OSDHud {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        visible: root.active && (OSDController.showVolume || OSDController.showBrightness)
    }

    onActiveChanged: if (root.active) authPrompt.focusInput();
    Component.onCompleted: if (root.active) authPrompt.focusInput();

    Connections {
        target: root.context

        function onUnlockInProgressChanged() {
            if (!root.context.unlockInProgress)
                authPrompt.clear();
        }
    }
}
