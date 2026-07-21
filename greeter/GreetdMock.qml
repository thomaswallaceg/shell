import QtQuick

// Dev-only stand-in for Quickshell.Services.Greetd's Greetd singleton.
// GreeterWindow picks this as its `backend` whenever Greetd.available is
// false, so the whole login flow (username -> password -> waiting -> launch)
// can be exercised while testing this file windowed (`qs -p greeter`, see
// README) without a real greetd socket — and so GreeterWindow itself never
// has to branch on Greetd.available beyond that one selection. Mirrors just
// the slice of the real singleton's API GreeterWindow actually drives:
// createSession/respond/launch and the authMessage/authFailure/error/
// readyToLaunch signals.
QtObject {
    id: root

    signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
    signal authFailure(string message)
    signal error(string message)
    signal readyToLaunch()
    // Mock-only, not part of the real Greetd API: real Greetd.launch()
    // replaces this whole process with the session command and never
    // returns, so GreeterWindow never needs to react to it finishing. The
    // mock can't actually do that, so it emits this instead once its fake
    // "launch" completes — GreeterWindow listens for it separately to show
    // a dev banner and reset back to the username step.
    signal mockLaunched()

    function createSession(username) {
        passwordPromptTimer.restart();
    }

    function respond(answer) {
        if (answer === "oops")
            // Dev-mode-only trigger for exercising the wrong-password path
            // without a real greetd socket to reject a real password against.
            authFailureTimer.restart();
        else
            readyTimer.restart();
    }

    function cancelSession() {
        passwordPromptTimer.stop();
        authFailureTimer.stop();
        readyTimer.stop();
    }

    function launch(command, env, detach) {
        root.mockLaunched();
    }

    property Timer passwordPromptTimer: Timer {
        interval: 400
        onTriggered: root.authMessage("Password", false, true, false)
    }

    // Bounces back to the username field on "wrong password", matching
    // agreety's default behavior (see GreeterWindow's real onAuthFailure).
    property Timer authFailureTimer: Timer {
        interval: 400
        onTriggered: root.authFailure("Wrong username or password")
    }

    property Timer readyTimer: Timer {
        interval: 400
        onTriggered: root.readyToLaunch()
    }
}
