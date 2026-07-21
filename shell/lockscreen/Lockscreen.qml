import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Wayland session lock (ext_session_lock_v1 via WlSessionLock), themed like
// the greeter but authenticating the already-logged-in user through
// LockContext/PamContext instead of greetd. Security-critical: `locked` must
// only ever be set back to false from LockContext.onUnlocked (a real PAM
// success) — never wire a plain escape-key/close handler into this, or the
// lock becomes bypassable (see AGENTS.md's lockscreen notes).
Scope {
    id: root

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

    // Which screen currently shows the auth card, mirroring GreeterWindow's
    // "biggest screen first, then whichever the mouse is over" behavior.
    property var activeScreen: mainScreen

    LockContext {
        id: lockContext
        onUnlocked: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock

        // Reset back to the main screen every time the lock re-engages,
        // rather than keeping wherever the mouse last was from a previous lock.
        onLockedChanged: if (locked) root.activeScreen = root.mainScreen

        WlSessionLockSurface {
            id: lockSurfaceWrapper

            LockSurface {
                anchors.fill: parent
                context: lockContext
                active: lockSurfaceWrapper.screen === root.activeScreen
                onPointerMoved: root.activeScreen = lockSurfaceWrapper.screen
            }
        }
    }

    // Manual trigger for testing/binding, e.g. `qs ipc call lockscreen lock`
    // from a niri keybind or an idle daemon. Intentionally no matching
    // `unlock` — only a successful PAM auth may clear the lock.
    IpcHandler {
        target: "lockscreen"

        function lock(): void {
            sessionLock.locked = true;
        }
    }
}
