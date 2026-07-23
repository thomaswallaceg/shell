import QtQuick
import Quickshell
import "../theme-switcher"

IconTextBarPill {
  id: pill

  // Lock + Log Out only make sense inside a live session (the bar). Lockscreen
  // and greeter leave this false so the menu is just sleep / reboot / poweroff.
  property bool showSessionActions: true
  // Session lock only allows one surface per output, so PopupWindow cannot
  // map there — render the menu inside the lock/greeter surface instead.
  property bool inlineMenu: false
  property bool menuOpen: false
  // Fullscreen Item to parent the in-surface menu onto. Required so the panel
  // isn't clipped/hit-test-rejected by the short top-right Row.
  property Item inlineMenuHost: null

  icon: "󰐥"
  iconColor: menuOpen ? Theme.accentPrimary : Theme.textSecondary

  readonly property var items: {
    const power = [
      { label: "Sleep", glyph: "󰒲", action: "suspend" },
      { label: "Restart", glyph: "󰜉", action: "reboot" },
      { label: "Shut Down", glyph: "󰐥", action: "shutdown" }
    ];
    if (!pill.showSessionActions)
      return power;
    return [
      { label: "Lock", glyph: "󰌾", action: "lock" },
      ...power,
      { label: "Log Out", glyph: "󰍃", action: "logout" }
    ];
  }

  function runAction(action) {
    switch (action) {
      case "lock":
        Quickshell.execDetached(["qs", "ipc", "call", "lockscreen", "lock"]);
        break;
      case "suspend":
        Quickshell.execDetached(["systemctl", "suspend"]);
        break;
      case "reboot":
        Quickshell.execDetached(["systemctl", "reboot"]);
        break;
      case "shutdown":
        Quickshell.execDetached(["systemctl", "poweroff"]);
        break;
      case "logout":
        Quickshell.execDetached(["niri", "msg", "action", "quit"]);
        break;
    }
  }

  function closeMenu() { menuOpen = false; }

  function repositionInlineMenu() {
    if (!inlineMenu || !menuOpen || !inlineMenuHost || !inlinePanel.item)
      return;
    const pos = inlineMenuHost.mapFromItem(
      pill, pill.width - inlinePanel.width, pill.height + 4);
    inlinePanel.x = pos.x;
    inlinePanel.y = pos.y;
  }

  Accessible.role: Accessible.Button
  Accessible.name: "Power menu"

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    z: 2
    onClicked: pill.menuOpen = !pill.menuOpen
  }

  Component {
    id: menuContent

    Rectangle {
      width: 160
      height: menuColumn.height + 8
      radius: 10
      // bgSurface contrasts against the lock/greeter bgBase fill; PopupWindow
      // over the desktop can sit on bgBase, but an in-surface menu cannot.
      color: Theme.bgSurface
      border.color: Theme.bgBorder
      border.width: 1

      Column {
        id: menuColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        width: parent.width - 8

        Repeater {
          model: pill.items

          Rectangle {
            id: row
            required property var modelData

            width: menuColumn.width
            height: 32
            radius: 6
            color: itemArea.containsMouse ? Theme.bgSelected : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              Text {
                height: parent.height
                text: row.modelData.glyph
                color: Theme.textSecondary
                font.pixelSize: ThemeEngine.fontSizeIcon
                font.family: ThemeEngine.fontFamily
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                height: parent.height
                text: row.modelData.label
                color: Theme.textPrimary
                font.pixelSize: ThemeEngine.fontSizeSm
                font.family: ThemeEngine.fontFamily
                verticalAlignment: Text.AlignVCenter
              }
            }

            MouseArea {
              id: itemArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              Accessible.role: Accessible.Button
              Accessible.name: row.modelData.label
              onClicked: {
                pill.closeMenu();
                pill.runAction(row.modelData.action);
              }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: popupMenu
    visible: !pill.inlineMenu && pill.menuOpen
    grabFocus: true
    color: "transparent"
    implicitWidth: popupLoader.item ? popupLoader.item.width : 160
    implicitHeight: popupLoader.item ? popupLoader.item.height : 0

    anchor.item: pill
    // Anchored to the pill's bottom-right corner, growing down-and-left —
    // this widget sits at the far right of the bar, so growing rightward
    // like the PopupAnchor default would push the menu off-screen.
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.Flip

    onVisibleChanged: {
      if (!visible && pill.menuOpen && !pill.inlineMenu)
        pill.menuOpen = false;
    }

    Loader {
      id: popupLoader
      sourceComponent: menuContent
      active: !pill.inlineMenu
    }
  }

  // Parent onto inlineMenuHost (fullscreen chrome) so the panel isn't stuck
  // inside the short top-right Row for stacking / hit-testing. WlSessionLockSurface
  // is not a QsWindow, so window.contentItem reparenting is a no-op there.
  Loader {
    id: inlinePanel
    parent: pill.inlineMenu && pill.menuOpen && pill.inlineMenuHost
      ? pill.inlineMenuHost
      : pill
    active: pill.inlineMenu && pill.menuOpen && pill.inlineMenuHost
    width: 160
    height: item ? item.height : 0
    z: 100
    sourceComponent: menuContent
    onLoaded: pill.repositionInlineMenu()
    onHeightChanged: pill.repositionInlineMenu()
  }

  Connections {
    target: pill
    function onMenuOpenChanged() {
      if (pill.menuOpen)
        Qt.callLater(pill.repositionInlineMenu);
    }
  }
}
