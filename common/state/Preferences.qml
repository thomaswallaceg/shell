pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Persisted preferences (theme, font, wallpaper): one JSON file per config root.
// The greeter instead reads the admin-owned file named by
// THOMAS_SHELL_PREFERENCES (see greeter/shell.qml), and never writes to it.
Singleton {
  id: root

  readonly property string systemFile: Quickshell.env("THOMAS_SHELL_PREFERENCES") || ""

  property alias theme: adapter.theme
  property alias fontFamily: adapter.fontFamily
  property alias wallpaper: adapter.wallpaper

  FileView {
    id: file
    path: root.systemFile !== "" ? root.systemFile : Quickshell.statePath("preferences.json")
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: {
      if (root.systemFile === "")
        writeAdapter();
    }

    JsonAdapter {
      id: adapter

      property string theme: ""
      property string fontFamily: ""
      property string wallpaper: ""
    }
  }
}
