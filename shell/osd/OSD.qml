import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../services"
import "../common/theme-switcher"

Scope {
  id: root

  property bool showVolume: false
  property bool showBrightness: false
  property real volumeValue: 0
  property bool volumeMuted: false
  property real brightnessValue: 0
  property real maxBrightness: 1
  property bool _brightnessReady: false

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio ?? null

    function onVolumeChanged() {
      root.volumeValue = Pipewire.defaultAudioSink.audio.volume;
      root.showVolume = true;
      volumeHideTimer.restart();
    }

    function onMutedChanged() {
      root.volumeMuted = Pipewire.defaultAudioSink.audio.muted;
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

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      // Same monitor as notifications — the smallest-resolution screen when
      // there's more than one, otherwise the only one there is.
      visible: (root.showVolume || root.showBrightness) && modelData === Displays.smallestScreen
      focusable: false
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell-osd"

      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      // Anchored only to the bottom: layer-shell centers a surface along any
      // axis it isn't anchored on, so leaving left/right unset centers it
      // horizontally.
      anchors {
        bottom: true
      }
      margins.bottom: 40

      implicitWidth: pillColumn.implicitWidth
      implicitHeight: pillColumn.implicitHeight

      Column {
        id: pillColumn
        anchors.fill: parent
        spacing: 12

        OSDPill {
          shown: root.showVolume
          label: root.volumeMuted ? "Mute" : Math.round(root.volumeValue * 100) + "%"
          value: root.volumeMuted ? 0 : root.volumeValue
          fillColor: root.volumeMuted ? Theme.textMuted : Theme.accentPrimary
          icon: {
            if (root.volumeMuted || root.volumeValue <= 0) return "󰖁";
            if (root.volumeValue < 0.33) return "󰕿";
            if (root.volumeValue < 0.66) return "󰖀";
            return "󰕾";
          }
          accessibleName: root.volumeMuted ? "Volume: muted" : "Volume: " + Math.round(root.volumeValue * 100) + "%"
        }

        OSDPill {
          shown: root.showBrightness
          label: Math.round(root.brightnessValue * 100) + "%"
          value: root.brightnessValue
          fillColor: Theme.accentOrange
          icon: "󰃠"
          accessibleName: "Brightness: " + Math.round(root.brightnessValue * 100) + "%"
        }
      }
    }
  }
}
