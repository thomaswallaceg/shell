pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.common.state

// Wallpapers are copied into our own state dir and used from there: whatever
// was picked can be moved or deleted afterwards
Singleton {
  id: root

  property string source: ""

  readonly property string storeDir: Quickshell.statePath("wallpaper")
  property string pendingPath: ""
  property string pendingDest: ""

  function storedPath(path) {
    const name = path.split("/").pop();
    const dot = name.lastIndexOf(".");
    let ext = dot > 0 ? name.slice(dot + 1).toLowerCase().replace(/[^a-z0-9]/g, "") : "";
    if (ext === "" || ext.length > 5)
      ext = "img";
    return root.storeDir + "/" + Date.now() + "." + ext;
  }

  function setSource(path) {
    const trimmed = (path || "").trim();
    if (trimmed === root.source)
      return;

    if (trimmed === "" || trimmed.startsWith(root.storeDir + "/")) {
      root.apply(trimmed);
      return;
    }

    root.pendingPath = trimmed;
    root.pendingDest = root.storedPath(trimmed);
    storeProc.running = false;
    storeProc.running = true;
  }

  function apply(path) {
    root.source = path;
    Preferences.wallpaper = path;
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

  // Copy via a temp file so a half-written wallpaper is never shown, then drop
  // any previous copy
  Process {
    id: storeProc
    running: false
    command: [
      "sh", "-c",
      'dir=$1; src=$2; dest=$3; mkdir -p "$dir" && cp -f -- "$src" "$dest.part" && mv -f -- "$dest.part" "$dest" && find "$dir" -maxdepth 1 -type f ! -name "$(basename "$dest")" -delete',
      "sh", root.storeDir, root.pendingPath, root.pendingDest
    ]
    onExited: exitCode => {
      if (root.pendingPath === "")
        return;
      if (exitCode === 0) {
        root.apply(root.pendingDest);
      } else {
        // Better a wallpaper that breaks if the file moves than none at all.
        console.warn("WallpaperController: could not copy wallpaper into", root.storeDir);
        root.apply(root.pendingPath);
      }
      root.pendingPath = "";
      root.pendingDest = "";
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
