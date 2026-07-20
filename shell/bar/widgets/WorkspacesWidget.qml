import QtQuick
import Quickshell
import "../../services"
import "../../common/theme-switcher"

// One pill per connected monitor, each containing a dot per workspace on that
// output — the active workspace's dot is enlarged, and the pill itself is
// outlined when its monitor currently holds keyboard focus. Purely a status
// display — not clickable, since focusing a workspace on another monitor via
// niri's IPC unavoidably steals input focus to that monitor too (niri has no
// way to just display a workspace without also focusing it).
Row {
  id: root
  spacing: 6

  readonly property var monitorGroups: {
    const groups = [];
    for (const ws of Niri.workspaces) {
      const last = groups.length > 0 ? groups[groups.length - 1] : null;
      const group = (last && last.output === ws.output) ? last : { output: ws.output, workspaces: [] };
      if (group !== last) groups.push(group);
      group.workspaces.push(ws);
    }

    // Order pills to match the monitors' physical layout (left-to-right,
    // then top-to-bottom) instead of niri's alphabetical-by-name ordering.
    const posByOutput = {};
    for (const screen of Quickshell.screens) posByOutput[screen.name] = { x: screen.x, y: screen.y };
    groups.sort((a, b) => {
      const pa = posByOutput[a.output] || { x: 0, y: 0 };
      const pb = posByOutput[b.output] || { x: 0, y: 0 };
      return pa.x - pb.x || pa.y - pb.y;
    });

    return groups;
  }

  Repeater {
    model: root.monitorGroups

    BarPill {
      id: monitorPill
      required property var modelData
      readonly property bool hasFocus: modelData.workspaces.some(w => w.focused)

      Accessible.role: Accessible.Grouping
      Accessible.name: "Monitor " + monitorPill.modelData.output

      implicitWidth: dotsRow.width + 16
      border.width: hasFocus ? 1 : 0
      border.color: Theme.accentPrimary

      Behavior on border.color {
        ColorAnimation { duration: 150 }
      }

      Row {
        id: dotsRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
          model: monitorPill.modelData.workspaces

          Rectangle {
            id: dot
            required property var modelData
            property bool urgentBlink: false

            Accessible.role: Accessible.StaticText
            Accessible.name: "Workspace " + dot.modelData.idx + (dot.modelData.active ? ", active" : "") + (dot.modelData.urgent ? ", urgent" : "")

            anchors.verticalCenter: parent.verticalCenter
            width: dot.modelData.active ? 10 : 6
            height: width
            radius: width / 2
            color: dot.modelData.active ? Theme.accentPrimary :
                   dot.modelData.urgent && urgentBlink ? Theme.accentRed : Theme.textMuted

            Behavior on width {
              NumberAnimation { duration: 150 }
            }

            Behavior on color {
              ColorAnimation { duration: 150 }
            }

            SequentialAnimation {
              loops: Animation.Infinite
              running: dot.modelData.urgent && !dot.modelData.active

              PropertyAction { target: dot; property: "urgentBlink"; value: true }
              PauseAnimation { duration: 500 }
              PropertyAction { target: dot; property: "urgentBlink"; value: false }
              PauseAnimation { duration: 500 }

              onStopped: dot.urgentBlink = false
            }
          }
        }
      }
    }
  }
}
