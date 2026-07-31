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

  FileView {
    id: confFile
    path: Quickshell.statePath("wallpaper.conf")
    onTextChanged: {
      const text = confFile.text().trim();
      if (text !== root.source)
        root.source = text;
    }
  }
}
