pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Shared volume/brightness OSD state. Session overlay, lock surface, and
// greeter all read this — layer-shell overlays are blanked by
// ext_session_lock_v1, and the greeter is a separate config entirely.
Singleton {
  id: root

  property bool showVolume: false
  property bool showBrightness: false
  property real volumeValue: 0
  property bool volumeMuted: false
  property real brightnessValue: 0
  property real maxBrightness: 1
  // Pipewire emits volume/mute while the sink comes up; suppress those so the
  // OSD doesn't flash on every shell start. Brightness seeds via its first read.
  property bool _volumeReady: false
  property bool _brightnessReady: false

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Timer {
    interval: 500
    running: true
    onTriggered: {
      const audio = Pipewire.defaultAudioSink?.audio;
      if (audio) {
        root.volumeValue = audio.volume;
        root.volumeMuted = audio.muted;
      }
      root._volumeReady = true;
    }
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio ?? null

    function onVolumeChanged() {
      root.volumeValue = Pipewire.defaultAudioSink.audio.volume;
      if (!root._volumeReady)
        return;
      root.showVolume = true;
      volumeHideTimer.restart();
    }

    function onMutedChanged() {
      root.volumeMuted = Pipewire.defaultAudioSink.audio.muted;
      if (!root._volumeReady)
        return;
      root.showVolume = true;
      volumeHideTimer.restart();
    }
  }

  Timer {
    id: volumeHideTimer
    interval: 1500
    onTriggered: root.showVolume = false
  }

  FileView {
    id: brightnessFile
    path: ""
    watchChanges: true
    onFileChanged: brightnessReadProc.running = true
  }

  Process {
    id: brightnessReadProc
    command: ["brightnessctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseInt(text.trim());
        if (!isNaN(val) && root.maxBrightness > 0) {
          root.brightnessValue = val / root.maxBrightness;
          if (root._brightnessReady) {
            root.showBrightness = true;
            brightnessHideTimer.restart();
          }
          root._brightnessReady = true;
        }
      }
    }
  }

  Process {
    id: backlightDiscovery
    command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length >= 2) {
          const max = parseInt(lines[1]);
          if (!isNaN(max) && max > 0) root.maxBrightness = max;
          brightnessFile.path = lines[0];
          brightnessReadProc.running = true;
        }
      }
    }
  }

  Timer {
    id: brightnessHideTimer
    interval: 1500
    onTriggered: root.showBrightness = false
  }
}
