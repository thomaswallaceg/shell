//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env THOMAS_SHELL_PREFERENCES=/etc/thomas-shell/greeter.json

import Quickshell
import qs

// Separate Quickshell config from the main shell.qml — this one is launched by
// greetd (via cage) before login, not as part of the niri+Quickshell session.
// See AGENTS.md "Planned additions" / README.md "Planned" for the split rationale.
Scope {
  GreeterWindow {}
}
