pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string source: ""

  function setSource(path) {
    const trimmed = (path || "").trim();
    if (trimmed === root.source)
      return;
    root.source = trimmed;
    confFile.setText(trimmed);
  }

  function clear() {
    setSource("");
  }

  function pick() {
    if (pickProc.running)
      return;
    pickProc.running = true;
  }

  FileView {
    id: confFile
    path: Quickshell.statePath("wallpaper.conf")
    onTextChanged: {
      const text = confFile.text().trim();
      if (text !== root.source)
        root.source = text;
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
