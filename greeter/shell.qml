//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import "."

// Separate Quickshell config from the main shell.qml — this one is launched by
// greetd (via cage) before login, not as part of the niri+Quickshell session.
// See AGENTS.md "Planned additions" / README.md "Planned" for the split rationale.
Scope {
  GreeterWindow {}
}
