import QtQuick
import Quickshell.Bluetooth
import "../../services"
import "../../common/theme-switcher"

IconTextBarPill {
  id: pill

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var connectedDevice: {
    const devices = Bluetooth.devices?.values ?? [];
    for (const device of devices) {
      if (device?.connected)
        return device;
    }
    return null;
  }

  visible: adapter !== null

  icon: {
    if (!adapter?.enabled)
      return "󰂲";
    if (connectedDevice)
      return "󰂱";
    if (adapter.discovering)
      return "󰂳";
    return "󰂯";
  }

  iconColor: {
    if (!adapter?.enabled)
      return Theme.textMuted;
    if (connectedDevice)
      return Theme.accentPrimary;
    return Theme.accentGreen;
  }

  label: {
    if (!adapter?.enabled)
      return "Off";
    if (!connectedDevice)
      return "On";
    const name = connectedDevice.name || connectedDevice.deviceName;
    if (connectedDevice.batteryAvailable)
      return name + " " + Math.round(connectedDevice.battery * 100) + "%";
    return name;
  }

  Accessible.role: Accessible.Button
  Accessible.name: {
    if (!adapter)
      return "Bluetooth";
    if (!adapter.enabled)
      return "Bluetooth: off";
    if (connectedDevice) {
      const name = connectedDevice.name || connectedDevice.deviceName;
      if (connectedDevice.batteryAvailable)
        return "Bluetooth: " + name + ", " + Math.round(connectedDevice.battery * 100) + "% battery";
      return "Bluetooth: " + name;
    }
    return "Bluetooth: on";
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Niri.openFloatingTui("bluetui")
  }
}
