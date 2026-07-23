import QtQuick
import Quickshell.Networking
import "../../services"
import "../../common/theme-switcher"
import "../../common/widgets"

IconTextBarPill {
  readonly property var activeConnection: {
    const devices = Networking.devices?.values ?? [];

    for (const device of devices) {
      if (device.type !== DeviceType.Wired)
        continue;
      if (!device.connected && device.state !== ConnectionState.Connected)
        continue;

      const network = device.network;
      if (network?.connected || network?.state === ConnectionState.Connected)
        return { type: "ethernet", label: network.name || device.name };

      return { type: "ethernet", label: device.name };
    }

    for (const device of devices) {
      if (device.type !== DeviceType.Wifi)
        continue;
      if (!device.connected && device.state !== ConnectionState.Connected)
        continue;

      const networks = device.networks?.values ?? [];
      for (const network of networks) {
        if (network?.connected || network?.state === ConnectionState.Connected)
          return { type: "wifi", label: network.name || device.name };
      }

      return { type: "wifi", label: device.name };
    }

    return { type: "disconnected", label: "Disconnected" };
  }

  icon: {
    if (activeConnection.type === "ethernet") return "󰈀";
    if (activeConnection.type === "wifi") return "󰖩";
    return "󰖪";
  }

  iconColor: activeConnection.type === "disconnected" ? Theme.textMuted : Theme.accentGreen
  label: activeConnection.label

  Accessible.role: Accessible.Button
  Accessible.name: {
    if (activeConnection.type === "ethernet") return "Network: Ethernet";
    if (activeConnection.type === "wifi") return "Network: WiFi " + activeConnection.label;
    return "Network: Disconnected";
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Niri.openFloatingTui("wlctl")
  }
}
