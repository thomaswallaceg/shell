import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs.common.theme

IconTextBarPill {
  id: pill

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery.ready && battery.isLaptopBattery
  readonly property int level: {
    const percent = battery.percentage;
    return percent <= 1 ? Math.round(percent * 100) : Math.round(percent);
  }
  // Device.state often lags on plug/unplug (PendingCharge, charge thresholds);
  // OnBattery tracks the AC adapter and updates immediately.
  readonly property bool charging: !UPower.onBattery

  property string statusLabel: ""

  property bool chargeLimitSupported: false
  property bool chargeLimitEnabled: false
  property bool chargeLimitSetting: false
  property int chargeStartThreshold: 75
  property int chargeEndThreshold: 80
  property string chargeBatteryPath: ""

  // Care badge when the limit is on and level is at/above the start threshold
  // (also during the right-click "Charge limit: …" flash).
  readonly property bool showChargeCare: chargeLimitSupported
    && chargeLimitEnabled
    && (
      statusLabel.startsWith("Charge limit:")
      || level >= chargeStartThreshold
    )

  readonly property string profileName: profileNameFor(PowerProfiles.profile)

  function profileNameFor(profile) {
    switch (profile) {
      case PowerProfile.PowerSaver: return "Power saver";
      case PowerProfile.Performance: return "Performance";
      default: return "Balanced";
    }
  }

  function cyclePowerProfile() {
    const current = PowerProfiles.profile;
    let next = PowerProfile.Balanced;
    if (current === PowerProfile.PowerSaver)
      next = PowerProfile.Balanced;
    else if (current === PowerProfile.Balanced)
      next = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
    else
      next = PowerProfile.PowerSaver;
    PowerProfiles.profile = next;
    statusLabel = profileNameFor(next);
    statusLabelTimer.restart();
  }

  // UPower only exposes on/off for the hwdb-configured start/end pair
  // (typically 75→80). Right-click toggles that limit.
  function cycleChargeLimit() {
    if (!chargeLimitSupported || chargeBatteryPath === "")
      return;
    const enable = !chargeLimitEnabled;
    chargeLimitSetProc.command = [
      "busctl", "call",
      "org.freedesktop.UPower", chargeBatteryPath,
      "org.freedesktop.UPower.Device",
      "EnableChargeThreshold", "b", enable ? "true" : "false"
    ];
    chargeLimitSetProc.running = false;
    chargeLimitSetting = true;
    chargeLimitSetProc.running = true;
    chargeLimitEnabled = enable;
    statusLabel = "Charge limit: " + (enable ? (chargeEndThreshold + "%") : "None");
    statusLabelTimer.restart();
  }

  function refreshChargeLimit() {
    chargeLimitReadProc.running = false;
    chargeLimitReadProc.running = true;
  }

  visible: present

  icon: {
    if (!present)
      return "";
    if (charging) {
      if (level >= 90) return "󰂅";
      if (level >= 80) return "󰂋";
      if (level >= 70) return "󰂊";
      if (level >= 60) return "󰢞";
      if (level >= 50) return "󰂉";
      if (level >= 40) return "󰢝";
      if (level >= 30) return "󰂈";
      if (level >= 20) return "󰂇";
      if (level >= 10) return "󰂆";
      return "󰢜";
    }
    if (level >= 90) return "󰁹";
    if (level >= 80) return "󰂂";
    if (level >= 70) return "󰂁";
    if (level >= 60) return "󰂀";
    if (level >= 50) return "󰁿";
    if (level >= 40) return "󰁾";
    if (level >= 30) return "󰁽";
    if (level >= 20) return "󰁼";
    if (level >= 10) return "󰁻";
    return "󰁺";
  }

  iconBadge: showChargeCare ? "󰒘" : ""
  iconBadgeColor: Theme.accentGreen

  // Only non-default profiles get a trailing cue (leaf / speedometer).
  trailingIcon: {
    switch (PowerProfiles.profile) {
      case PowerProfile.PowerSaver: return "󰌪";
      case PowerProfile.Performance: return "󰓅";
      default: return "";
    }
  }
  trailingIconColor: {
    switch (PowerProfiles.profile) {
      case PowerProfile.PowerSaver: return Theme.accentGreen;
      case PowerProfile.Performance: return Theme.accentRed;
      default: return Theme.textMuted;
    }
  }

  label: statusLabel !== "" ? statusLabel : (level + "%")

  iconColor: {
    if (charging) return Theme.accentGreen;
    if (level > 30) return Theme.accentGreen;
    if (level > 15) return Theme.accentOrange;
    return Theme.accentRed;
  }

  Accessible.role: Accessible.Button
  Accessible.name: {
    let name = "Battery: " + level + "%"
      + (charging ? ", charging" : "")
      + ", " + profileName;
    if (chargeLimitSupported) {
      name += chargeLimitEnabled
        ? ", charge limit " + chargeEndThreshold + "%"
        : ", no charge limit";
    }
    return name;
  }

  Timer {
    id: statusLabelTimer
    interval: 1500
    onTriggered: pill.statusLabel = ""
  }

  // Pick up external toggles (e.g. GNOME Settings).
  Timer {
    interval: 15000
    running: pill.present
    repeat: true
    onTriggered: pill.refreshChargeLimit()
  }

  Component.onCompleted: refreshChargeLimit()
  onPresentChanged: if (present) refreshChargeLimit()

  Process {
    id: chargeLimitReadProc
    // First BAT* device that reports ChargeThresholdSupported.
    command: [
      "sh", "-c",
      'for path in $(upower -e); do ' +
      '  case "$path" in */battery_BAT*|*/battery_bat*) ;; *) continue ;; esac; ' +
      '  supported=$(busctl get-property org.freedesktop.UPower "$path" ' +
      '    org.freedesktop.UPower.Device ChargeThresholdSupported 2>/dev/null) || continue; ' +
      '  [ "$supported" = "b true" ] || continue; ' +
      '  enabled=$(busctl get-property org.freedesktop.UPower "$path" ' +
      '    org.freedesktop.UPower.Device ChargeThresholdEnabled) || continue; ' +
      '  start=$(busctl get-property org.freedesktop.UPower "$path" ' +
      '    org.freedesktop.UPower.Device ChargeStartThreshold) || continue; ' +
      '  end=$(busctl get-property org.freedesktop.UPower "$path" ' +
      '    org.freedesktop.UPower.Device ChargeEndThreshold) || continue; ' +
      '  printf "%s\\n%s\\n%s\\n%s\\n" "$path" "$enabled" "$start" "$end"; ' +
      '  exit 0; ' +
      'done; exit 1'
    ]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length < 4) {
          pill.chargeLimitSupported = false;
          pill.chargeLimitEnabled = false;
          pill.chargeBatteryPath = "";
          return;
        }
        pill.chargeBatteryPath = lines[0];
        pill.chargeLimitSupported = true;
        pill.chargeLimitEnabled = lines[1] === "b true";
        const start = parseInt(String(lines[2]).replace(/^u\s+/, ""), 10);
        const end = parseInt(String(lines[3]).replace(/^u\s+/, ""), 10);
        if (!isNaN(start))
          pill.chargeStartThreshold = start;
        if (!isNaN(end))
          pill.chargeEndThreshold = end;
      }
    }
  }

  Process {
    id: chargeLimitSetProc
    running: false
    onRunningChanged: {
      if (running || !pill.chargeLimitSetting)
        return;
      pill.chargeLimitSetting = false;
      pill.refreshChargeLimit();
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        pill.cycleChargeLimit();
      else
        pill.cyclePowerProfile();
    }
  }
}
