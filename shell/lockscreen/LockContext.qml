import Quickshell
import Quickshell.Services.Pam
import QtQuick

// PamContext for the logged-in user, shared by every screen's LockSurface.
// Uses its own pam service (pam/auth.conf).
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
