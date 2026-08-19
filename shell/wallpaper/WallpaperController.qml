pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.common.state

Singleton {
  id: root

  property string source: ""

  function setSource(path) {
    const trimmed = (path || "").trim();
    if (trimmed === root.source)
      return;
    root.source = trimmed;
    Preferences.wallpaper = trimmed;
  }

  function clear() {
    setSource("");
  }

  function pick() {
    if (pickProc.running)
      return;
    pickProc.running = true;
  }

  Connections {
    target: Preferences
    function onWallpaperChanged() {
      if (Preferences.wallpaper !== root.source)
        root.source = Preferences.wallpaper;
    }
  }

  Process {
    id: pickProc
    command: [
      "zenity",
      "--file-selection",
      "--title=Choose wallpaper",
      "--file-filter=Image files | *.png *.jpg *.jpeg *.webp *.bmp *.gif",
      "--file-filter=All files | *"
    ]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim();
        if (path)
          root.setSource(path);
      }
    }
  }
}
