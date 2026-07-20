import QtQuick
import Quickshell.Services.UPower
import "../../common/theme-switcher"

IconTextBarPill {
  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery?.ready && battery.isLaptopBattery
  readonly property int level: {
    if (!battery)
      return 0;
    const percent = battery.percentage;
    return percent <= 1 ? Math.round(percent * 100) : Math.round(percent);
  }
  readonly property bool charging: battery?.state === UPowerDeviceState.Charging

  visible: present

  icon: {
    if (!present || charging)
      return "";
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

  label: level + "%"

  iconColor: {
    if (charging) return Theme.accentGreen;
    if (level > 20) return Theme.accentGreen;
    if (level > 10) return Theme.accentOrange;
    return Theme.accentRed;
  }

  Accessible.role: Accessible.StaticText
  Accessible.name: "Battery: " + level + "%"
}
