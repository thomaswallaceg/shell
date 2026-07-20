pragma Singleton

import QtQuick
import Quickshell

// Shared multi-monitor topology helpers, used by any shell element that
// needs to reason about which screen(s) it should appear on (the bar,
// notifications, ...).
Singleton {
  id: root

  readonly property bool singleMonitor: Quickshell.screens.length <= 1

  // The screen with the smallest area (width * height) — the one "least
  // likely to be a primary/main display" when there's more than one.
  readonly property var smallestScreen: {
    const screens = Quickshell.screens;
    if (!screens || screens.length === 0) return null;
    let smallest = screens[0];
    for (let i = 1; i < screens.length; i++) {
      if (screens[i].width * screens[i].height < smallest.width * smallest.height)
        smallest = screens[i];
    }
    return smallest;
  }
}
