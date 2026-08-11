import QtQuick
import Quickshell.Io
import qs.common.osd
import qs.common.theme
import qs.common.widgets

IconTextBarPill {
  id: pill

  property real brightnessValue: 0

  visible: OSDController.backlightPath !== ""
  icon: "󰃠"
  iconColor: Theme.accentOrange
  label: Math.round(brightnessValue * 100) + "%"

  Accessible.role: Accessible.StaticText
  Accessible.name: "Brightness: " + Math.round(brightnessValue * 100) + "%"

  FileView {
    id: brightnessFile
    path: OSDController.backlightPath
    watchChanges: true
    onFileChanged: brightnessReadProc.running = true
  }

  Process {
    id: brightnessReadProc
    command: ["brightnessctl", "get"]
    running: OSDController.backlightPath !== ""
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseInt(text.trim());
        if (!isNaN(val) && OSDController.maxBrightness > 0)
          pill.brightnessValue = val / OSDController.maxBrightness;
      }
    }
  }

  Process {
    id: brightnessSetProc
    running: false
  }

  WheelStepMouseArea {
    anchors.fill: parent
    onStepped: up => {
      // -n keeps at least 1; 0 blanks intel_backlight entirely.
      brightnessSetProc.command = up
        ? ["brightnessctl", "-n", "set", "5%+"]
        : ["brightnessctl", "-n", "set", "5%-"];
      brightnessSetProc.running = true;
    }
  }
}
