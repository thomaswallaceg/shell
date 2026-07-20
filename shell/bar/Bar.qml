import Quickshell
import QtQuick
import Quickshell.Io
import "../services"
import "../common/theme-switcher"
import "widgets"

Scope {
  id: root
  property bool barVisible: true

  // Typography and bar height live in ThemeEngine — widgets use ThemeEngine.* directly.

  // Visibility behavior: with a single monitor the bar auto-hides and only
  // reveals on hover of the screen's top edge. With multiple monitors it's
  // permanently shown, but only on the smallest-resolution one (usually the
  // one least likely to be a primary/main display). Screen topology lives in
  // Displays.qml (shared with notifications and any other monitor-aware module).
  // Only meaningful in singleMonitor mode — whether the auto-hidden bar is
  // currently revealed due to hover. Toggled instantly by hover, with no
  // artificial delay — the slide animation itself provides the transition.
  property bool barRevealed: false

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barVisible = !root.barVisible; }
    // Bind to a single key in niri with repeat enabled: each call reveals the
    // bar and (re)starts a 1s countdown to hide it again — a tap peeks
    // briefly, holding the key (repeat firing peek() over and over) keeps it
    // open continually until released.
    function peek(): void {
      root.barRevealed = true;
      peekTimer.restart();
    }
  }

  Timer {
    id: peekTimer
    interval: 2000
    repeat: false
    onTriggered: root.barRevealed = false
  }

  // Thin invisible strip at the very top of the screen, only present in
  // singleMonitor mode while the bar itself is hidden — its sole purpose is
  // detecting the hover that reveals the real bar (a hidden PanelWindow
  // can't receive pointer events itself).
  PanelWindow {
    id: hoverTrigger
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: root.barVisible && Displays.singleMonitor

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: 4
    color: "transparent"
    exclusiveZone: 0

    HoverHandler {
      onHoveredChanged: {
        if (hovered) root.barRevealed = true;
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData
      readonly property bool isTargetScreen: Displays.singleMonitor || modelData === Displays.smallestScreen
      // Always "revealed" outside of autohide mode; in autohide mode this
      // tracks hover state directly, with no delay.
      readonly property bool revealed: !Displays.singleMonitor || root.barRevealed

      // Stay mapped while the slide-out animation plays so it's visible,
      // then unmap once at rest hidden so the top edge is fully click-through.
      visible: root.barVisible && isTargetScreen && (!Displays.singleMonitor || revealed || slideAnim.running)
      // Auto-hide (single monitor) mode overlays the bar without pushing other
      // windows down; the always-shown (multi-monitor) mode reserves its full
      // height like a normal panel.
      exclusiveZone: Displays.singleMonitor ? 0 : ThemeEngine.barHeight

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: ThemeEngine.barHeight
      color: "transparent"

      HoverHandler {
        onHoveredChanged: {
          if (Displays.singleMonitor) root.barRevealed = hovered;
        }
      }

      Rectangle {
        id: barSurface
        anchors.left: parent.left
        anchors.right: parent.right
        height: ThemeEngine.barHeight
        y: barWindow.revealed ? 0 : -height
        color: Theme.bgBase

        Behavior on y {
          NumberAnimation { id: slideAnim; duration: 160; easing.type: Easing.OutQuad }
        }

        Item {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10

          // Left section: CPU + Temperature + Workspaces + Now Playing
          Row {
            id: leftSection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            CpuWidget {}
            TemperatureWidget {}
            WorkspacesWidget {}
            NowPlayingWidget {}
          }

          // Center section: Window Title (truly centered in bar)
          Item {
            anchors.centerIn: parent
            height: parent.height
            width: Math.max(0, parent.width - 2 * Math.max(leftSection.width, rightSection.width) - 32)

            WindowTitleWidget { anchors.fill: parent }
          }

          // Right section: System Tray + Volume + Brightness + Network/Battery + Time
          Row {
            id: rightSection
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            SystemTrayWidget {}
            VolumeWidget {}
            BrightnessWidget {}
            NetworkWidget {}
            BluetoothWidget {}
            BatteryWidget {}
            TimeWidget {}
          }
        }
      }
    }
  }
}
