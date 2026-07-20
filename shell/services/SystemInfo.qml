pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string cpuUsage: "0%"
  property string memoryUsage: "0%"
  property string temperature: "0°C"

  // CPU Usage
  Process {
    id: cpuProc
    command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{printf \"%2d%%\", int(100 - $1 + 0.5)}'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        // trimEnd (not trim) — a leading space is intentional padding to
        // prevent the widget width from shifting between 1- and 2-digit values.
        root.cpuUsage = text.replace(/\s+$/, "")
      }
    }
  }

  // Memory Usage
  Process {
    id: memProc
    command: ["sh", "-c", "free | grep Mem | awk '{printf \"%.1f%%\", ($3/$2) * 100.0}'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.memoryUsage = text.trim()
      }
    }
  }

  // Temperature
  Process {
    id: tempProc
    command: ["sh", "-c", "v=$(sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | head -1 | grep -oE '[+-][0-9]+(\\.[0-9]+)?' | head -1); if [ -n \"$v\" ]; then printf '%.0f°C' \"${v#+}\"; else printf 'N/A'; fi"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.temperature = text.trim() || "N/A"
      }
    }
  }

  // Update timer
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      cpuProc.running = true
      memProc.running = true
      tempProc.running = true
    }
  }
}
