import QtQuick
import Quickshell.Io
import "../../common/theme-switcher"
import "../../common/widgets"

IconTextBarPill {
  id: pill

  property real brightnessValue: 0
  property real brightnessMax: 1

  visible: brightnessFile.path !== ""
  icon: "󰃠"
  iconColor: Theme.accentOrange
  label: Math.round(brightnessValue * 100) + "%"

  Accessible.role: Accessible.StaticText
  Accessible.name: "Brightness: " + Math.round(brightnessValue * 100) + "%"

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
        if (!isNaN(val) && pill.brightnessMax > 0)
          pill.brightnessValue = val / pill.brightnessMax;
      }
    }
  }

  Process {
    id: brightnessSetProc
    running: false
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
          if (!isNaN(max) && max > 0) pill.brightnessMax = max;
          brightnessFile.path = lines[0];
          brightnessReadProc.running = true;
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onWheel: (wheel) => {
      brightnessSetProc.command = wheel.angleDelta.y > 0
        ? ["brightnessctl", "set", "5%+"]
        : ["brightnessctl", "set", "5%-"];
      brightnessSetProc.running = true;
    }
  }
}
