pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string cpuUsage: "0%"
  property string temperature: "0°C"

  Process {
    id: cpuProc
    // Two /proc/stat samples; idle+iowait excluded from busy (same as btop).
    // Leading space pads 1-digit values so the widget width stays stable.
    command: ["sh", "-c", "awk 'BEGIN { getline < \"/proc/stat\"; split($0, a); close(\"/proc/stat\"); t1=a[2]+a[3]+a[4]+a[5]+a[6]+a[7]+a[8]+a[9]; i1=a[5]+a[6]; system(\"sleep 0.5\"); getline < \"/proc/stat\"; split($0, b); t2=b[2]+b[3]+b[4]+b[5]+b[6]+b[7]+b[8]+b[9]; i2=b[5]+b[6]; dt=t2-t1; if (dt<=0) { printf \" 0%%\"; exit } printf \"%2d%%\", int((dt-(i2-i1))*100/dt+0.5) }'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.cpuUsage = text.replace(/\s+$/, "")
      }
    }
  }



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

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      cpuProc.running = true
      tempProc.running = true
    }
  }
}
