import QtQuick
import Quickshell.Services.UPower
import "../../common/theme-switcher"
import "../../common/widgets"

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

  property string profileLabel: ""

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
    profileLabel = profileNameFor(next);
    profileLabelTimer.restart();
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

  label: profileLabel !== "" ? profileLabel : (level + "%")

  iconColor: {
    if (charging) return Theme.accentGreen;
    if (level > 30) return Theme.accentGreen;
    if (level > 15) return Theme.accentOrange;
    return Theme.accentRed;
  }

  Accessible.role: Accessible.Button
  Accessible.name: "Battery: " + level + "%"
    + (charging ? ", charging" : "")
    + ", " + profileName

  Timer {
    id: profileLabelTimer
    interval: 1500
    onTriggered: pill.profileLabel = ""
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.cyclePowerProfile()
  }
}
