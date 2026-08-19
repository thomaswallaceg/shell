pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Single on-disk JSON file for every shell preference that needs to persist
// across restarts (theme, font, wallpaper, ...) — previously three separate
// flat .conf files (theme.conf/font.conf/wallpaper.conf), each with its own
// FileView plumbing scattered across the singleton that owned it. One
// JsonAdapter here instead: a new preference is one more `property`, not a
// new file + FileView + parsing.
//
// Still per-config-root (Quickshell.statePath), same as before — the greeter
// and main shell each get their own preferences.json rather than sharing
// one, since they're separate config roots (see AGENTS.md's module
// resolution notes). That's a separate concern from *this* file being
// singular per root.
Singleton {
  id: root

  property alias theme: adapter.theme
  property alias fontFamily: adapter.fontFamily
  property alias wallpaper: adapter.wallpaper

  FileView {
    id: file
    path: Quickshell.statePath("preferences.json")
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter

      property string theme: ""
      property string fontFamily: ""
      property string wallpaper: ""
    }
  }
}
