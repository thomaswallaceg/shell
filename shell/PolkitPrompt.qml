import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import qs.common.panel
import qs.common.theme
import qs.services

// Makes the shell the session's polkit authentication agent, so `pkexec` and
// friends prompt in the shell's own styling instead of needing an external
// agent (polkit-gnome et al) whose binary path differs per distro. Same shape
// as the lockscreen: Quickshell owns the protocol, common/panel/AuthPrompt.qml
// owns the looks.
//
// Only one agent may register per session — disable any other one first, or
// registration fails (the warning below says so).
//
// A request that arrives while the session is locked is deliberately left
// pending rather than cancelled: ext-session-lock shows only lock surfaces, so
// this prompt is hidden until unlock and then appears. That's what the
// external agents do too (polkit-gnome and polkit-kde have no lock awareness
// at all), and a cancelled request is the more surprising outcome.
Scope {
    id: root

    readonly property var flow: agent.flow

    // A flow exists from the moment a request starts until it completes; the
    // prompt is only shown while it's live.
    readonly property bool active: flow !== null && !flow.isCompleted

    // Tab (or a click on the name) only moves which account the card shows;
    // polkit isn't told until a password is actually being typed for it. That
    // matters because a switch isn't free: AuthFlow::setSelectedIdentity
    // cancels the running session, and the abandoned helper's PAM stack fails,
    // which pam_faillock records as a real failed login against the account
    // being left (verified: three switches put three `SVC polkit-1` entries in
    // `faillock --user`, and the default deny=3 then locks the account). So
    // cycling through the names costs nothing, and committing to one costs a
    // single tally that a successful authentication clears again.
    //
    // The first keystroke is the commit point rather than Enter because
    // AuthFlow::setupSession leaves isResponseRequired and inputPrompt at the
    // values the cancelled session set, and the replacement session writes the
    // same ones back ("Password: " for either account) — so nothing signals
    // that the new session is ready, and a password held until Enter would
    // have no safe moment to go out. Typing one gives the new session the
    // moment it needs.
    // -1 means "whatever polkit picked".
    property int pendingIdentityIndex: -1
    readonly property int shownIdentityIndex: pendingIdentityIndex >= 0 ? pendingIdentityIndex : selectedIdentityIndex

    function flushPendingIdentity() {
        const index = root.pendingIdentityIndex;
        root.pendingIdentityIndex = -1;

        if (!root.flow || index < 0 || index === root.selectedIdentityIndex)
            return;

        const list = root.flow.identities;
        if (!list || index >= list.length)
            return;

        identitySwitchGrace.restart();
        root.flow.selectedIdentity = list[index];
    }

    // The failure the cancelled session reports isn't the user's.
    Timer {
        id: identitySwitchGrace
        interval: 1000
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            if (identitySwitchGrace.running) {
                identitySwitchGrace.stop();
                return;
            }

            const detail = root.flow ? root.flow.supplementaryMessage : "";
            // Logged as well so the journal shows whether polkit gave a reason
            // or we fell back to our own wording.
            console.log("PolkitPrompt: authentication failed, polkit said:", detail === "" ? "(nothing)" : detail);
            root.statusText = detail !== "" ? detail : "Authentication failed";
            root.statusIsError = true;
        }
    }

    // Which screen shows the card: niri's focused output when the request
    // arrives, and after that whichever screen the pointer moves to, like the
    // lockscreen. Note the fields are per-screen, so text typed before the
    // card moves stays behind on the old one.
    property string promptScreen: ""

    // polkit can allow more than one account for an action (root, or anyone in
    // the admin group), and hands the agent the whole list with its own pick
    // already selected. These drive the card's chooser row; the index maps
    // straight back into flow.identities.
    readonly property var identityNames: {
        const out = [];
        const list = flow ? flow.identities : null;
        if (!list)
            return out;
        for (let i = 0; i < list.length; i++) {
            const identity = list[i];
            if (!identity)
                continue;
            out.push(identity.displayName !== "" ? identity.displayName : "uid " + identity.id);
        }
        return out;
    }

    readonly property int selectedIdentityIndex: {
        const list = flow ? flow.identities : null;
        const selected = flow ? flow.selectedIdentity : null;
        if (!list || !selected)
            return -1;
        for (let i = 0; i < list.length; i++) {
            const identity = list[i];
            if (!identity)
                continue;
            // The same object in practice; the id/name comparison covers a
            // list that hands out a fresh wrapper per read.
            if (identity === selected
                || (identity.id === selected.id && identity.displayName === selected.displayName))
                return i;
        }
        return -1;
    }

    // polkit doesn't reliably fill supplementaryMessage on a bad password —
    // the failure arrives as a signal instead, so keep our own status line and
    // clear it when the next attempt is sent.
    property string statusText: ""
    property bool statusIsError: false

    onActiveChanged: {
        if (!active)
            return;
        promptScreen = Niri.focusedOutput;
        statusText = "";
        statusIsError = false;
        pendingIdentityIndex = -1;
    }

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: {
            if (!isRegistered)
                console.warn("PolkitPrompt: not registered as the polkit agent — is another agent running?");
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: promptWindow
            required property var modelData
            screen: modelData

            // Every screen gets the dimmed surface, so there's nothing left to
            // click or type into on the other monitor; one of them shows the
            // prompt. Falls back to the bar's screen if niri didn't tell us
            // which output is focused.
            readonly property bool isPromptScreen: root.promptScreen !== ""
                ? modelData.name === root.promptScreen
                : modelData === Displays.smallestScreen
            visible: root.active
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-polkit"
            // Without this the bar's exclusive zone shrinks this surface and
            // leaves the bar uncovered — and clickable — above the dim.
            exclusionMode: ExclusionMode.Ignore
            // Blur what's behind the dim (niri implements the background-effect
            // protocol, so this needs nothing in the niri config).
            BackgroundEffect.blurRegion: Region { item: dim }
            // *Every* surface grabs the keyboard, not just the one showing the
            // card: niri hands keyboard focus to the focused output, so a
            // surface that asked for nothing leaves the windows underneath it
            // typable on that monitor.
            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Layer-shell focus doesn't stop the compositor acting on its own
            // keybinds, so Mod+… would still switch workspaces out from under
            // an open prompt. niri implements zwp_keyboard_shortcuts_inhibit.
            ShortcutInhibitor {
                window: promptWindow
                enabled: root.active
                onCancelled: console.warn("PolkitPrompt: compositor revoked the shortcut inhibitor")
            }

            // Like the lockscreen: the card follows the pointer, so if the
            // keyboard ended up on another monitor you just move the mouse
            // there instead of hunting for the prompt. The guard ignores the
            // position report every surface gets when it first appears.
            property bool pointerTrackingArmed: false

            HoverHandler {
                onPointChanged: {
                    if (!promptWindow.pointerTrackingArmed) {
                        promptWindow.pointerTrackingArmed = true;
                        return;
                    }
                    root.promptScreen = promptWindow.modelData.name;
                }
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                id: dim
                anchors.fill: parent
                color: Theme.bgBase
                // Light enough that the blurred windows behind stay
                // recognisable; the prompt sits on its own opaque panel.
                opacity: 0.65

                // Clicking the dim cancels: Escape is otherwise the only way
                // out, which leaves a mouse-only user stuck. Clicks on the
                // panel itself are swallowed by its own MouseArea below.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.flow)
                            root.flow.cancelAuthenticationRequest();
                    }
                }
            }

            // The clock and key hints sit outside the card in colours meant
            // for a solid background, so give them the same opaque bgBase the
            // lockscreen uses (LockSurface.qml) rather than restyling the
            // shared AuthPrompt.
            Rectangle {
                anchors.centerIn: prompt
                width: prompt.width + 80
                height: prompt.height + 56
                visible: prompt.visible
                radius: 28
                color: Theme.bgBase

                // Keeps clicks on (or beside) the card from reaching the dim
                // and cancelling the request.
                MouseArea {
                    anchors.fill: parent
                }
            }

            AuthPrompt {
                id: prompt
                anchors.centerIn: parent
                visible: promptWindow.isPromptScreen

                // `message` is polkit's human-readable description of the
                // action ("Authentication is required to …"), `inputPrompt`
                // the backend's field label ("Password:").
                // Whose password is wanted — the lockscreen shows the username
                // in the same spot. polkit's Identity carries displayName and
                // id (the uid).
                // The account itself is shown by the picker below, so the
                // title stays the one constant line on the card.
                title: "Authentication required"
                // polkit's own sentence ("Authentication is required to …"),
                // which is the part that actually varies.
                subtitle: root.flow ? root.flow.message : ""
                placeholder: root.flow && root.flow.inputPrompt !== "" ? root.flow.inputPrompt : "Password"
                accessibleName: placeholder
                // polkit can ask for something that should be echoed (a PIN
                // pad code, say) rather than a password.
                echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                // Also gated on isCompleted so a finished flow can't leave the
                // field stuck disabled behind an "Authenticating…" line.
                waiting: root.flow ? !root.flow.isResponseRequired && !root.flow.isCompleted : false
                helpText: root.statusText !== "" ? root.statusText : (root.flow ? root.flow.supplementaryMessage : "")
                helpTextStatus: root.statusIsError || (root.flow && root.flow.supplementaryIsError) ? "error" : "normal"
                // The chooser row hides itself when there's only one account,
                // so the hint for it comes and goes with it.
                identityNames: root.identityNames
                selectedIdentityIndex: root.shownIdentityIndex
                keyHints: root.identityNames.length > 1
                    ? [
                        { key: "⏎", label: "authenticate" },
                        { key: "⇥", label: "switch user" },
                        { key: "esc", label: "cancel" }
                    ]
                    : [
                        { key: "⏎", label: "authenticate" },
                        { key: "esc", label: "cancel" }
                    ]

                onActivated: text => {
                    if (!root.flow)
                        return;

                    // Enter without having typed anything: take it as picking
                    // the account rather than submitting an empty password,
                    // which polkit would count as a failed attempt.
                    if (root.pendingIdentityIndex >= 0) {
                        root.flushPendingIdentity();
                        return;
                    }

                    identitySwitchGrace.stop();
                    root.statusText = "";
                    root.statusIsError = false;
                    root.flow.submit(text);
                }

                // Switching accounts empties the field, so the first real
                // keystroke after a switch is what commits it.
                onTextEdited: text => {
                    if (text !== "")
                        root.flushPendingIdentity();
                }

                onCancelled: {
                    if (root.flow)
                        root.flow.cancelAuthenticationRequest();
                }

                onIdentitySelected: index => {
                    if (index < 0 || index >= root.identityNames.length || index === root.shownIdentityIndex)
                        return;

                    // Whatever was typed was the other account's password.
                    prompt.clear();
                    root.statusText = "";
                    root.statusIsError = false;
                    root.pendingIdentityIndex = index;
                    prompt.focusInput();
                }
            }

            onVisibleChanged: {
                promptWindow.pointerTrackingArmed = false;
                if (visible && promptWindow.isPromptScreen)
                    prompt.focusInput();
                else
                    prompt.clear();
            }

            // Focus follows the card when the pointer moves it to this screen.
            onIsPromptScreenChanged: {
                if (promptWindow.visible && promptWindow.isPromptScreen)
                    prompt.focusInput();
            }
        }
    }
}
