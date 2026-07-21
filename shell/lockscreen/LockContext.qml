import Quickshell
import Quickshell.Services.Pam
import QtQuick

// Wraps a PamContext authenticating the currently logged-in user, shared by
// every screen's LockSurface (see Lockscreen.qml). Uses a dedicated pam
// service (pam/auth.conf) rather than a system one like "login"/"sudo", since
// those can carry unrelated behavior (e.g. failure delays, extra prompts)
// that isn't a good fit for a lockscreen prompt — see Quickshell's
// Quickshell.Services.Pam docs on writing pam configurations.
QtObject {
    id: root

    signal unlocked()

    property string currentText: ""
    property bool unlockInProgress: false
    property string helpText: ""
    property string helpTextStatus: "normal" // normal | error

    onCurrentTextChanged: {
        root.helpText = "";
        root.helpTextStatus = "normal";
    }

    function tryUnlock() {
        if (root.currentText === "" || root.unlockInProgress)
            return;
        root.unlockInProgress = true;
        pam.start();
    }

    property PamContext pam: PamContext {
        configDirectory: "pam"
        config: "auth.conf"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText);
            else if (this.message) {
                root.helpText = this.message;
                root.helpTextStatus = this.messageIsError ? "error" : "normal";
            }
        }

        onCompleted: result => {
            root.unlockInProgress = false;
            if (result === PamResult.Success) {
                root.unlocked();
            } else {
                root.currentText = "";
                root.helpText = "Wrong password";
                root.helpTextStatus = "error";
            }
        }
    }
}
