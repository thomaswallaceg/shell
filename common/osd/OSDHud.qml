import QtQuick
import "../theme-switcher"

// The volume/brightness pill stack — shared by the session overlay, lock
// surface, and greeter (same visual, different host surface).
Column {
  id: root

  spacing: 12

  OSDPill {
    shown: OSDController.showVolume
    label: OSDController.volumeMuted ? "Mute" : Math.round(OSDController.volumeValue * 100) + "%"
    value: OSDController.volumeMuted ? 0 : OSDController.volumeValue
    fillColor: OSDController.volumeMuted ? Theme.textMuted : Theme.accentPrimary
    icon: {
      if (OSDController.volumeMuted || OSDController.volumeValue <= 0) return "󰖁";
      if (OSDController.volumeValue < 0.33) return "󰕿";
      if (OSDController.volumeValue < 0.66) return "󰖀";
      return "󰕾";
    }
    accessibleName: OSDController.volumeMuted
      ? "Volume: muted"
      : "Volume: " + Math.round(OSDController.volumeValue * 100) + "%"
  }

  OSDPill {
    shown: OSDController.showBrightness
    label: Math.round(OSDController.brightnessValue * 100) + "%"
    value: OSDController.brightnessValue
    fillColor: Theme.accentOrange
    icon: "󰃠"
    accessibleName: "Brightness: " + Math.round(OSDController.brightnessValue * 100) + "%"
  }
}
