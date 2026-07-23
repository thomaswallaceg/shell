import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

// Fullscreen confirm chrome for PowerController — parented onto a lock/greeter
// surface or a session overlay PanelWindow. Only visible when inhibitors were
// found for a pending reboot/shutdown.
Item {
  id: root

  visible: PowerController.confirmOpen
  z: 10001

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape) {
      PowerController.cancel();
      event.accepted = true;
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      PowerController.confirm();
      event.accepted = true;
    }
  }

  onVisibleChanged: {
    if (visible)
      forceActiveFocus();
  }

  MouseArea {
    anchors.fill: parent
    onClicked: PowerController.cancel()
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.bgOverlay
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: 420
    height: Math.min(cardLayout.implicitHeight + 32, parent.height - 48)
    radius: 16
    color: Theme.bgBase
    border.color: Theme.bgBorder
    border.width: 1

    MouseArea {
      anchors.fill: parent
      // Keep clicks on the card from hitting the dismiss layer.
    }

    ColumnLayout {
      id: cardLayout
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      Text {
        text: PowerController.pendingLabel + "?"
        color: Theme.textPrimary
        font.pixelSize: ThemeEngine.fontSizeLg
        font.family: ThemeEngine.fontFamily
        font.bold: true
        Layout.fillWidth: true
      }

      Text {
        text: "These apps are delaying shutdown. " +
              "You can still " + PowerController.pendingVerb + "."
        color: Theme.textSecondary
        font.pixelSize: ThemeEngine.fontSizeSm
        font.family: ThemeEngine.fontFamily
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      Flickable {
        id: listFlick
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(inhibitColumn.implicitHeight, 220)
        contentHeight: inhibitColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: inhibitColumn
          width: listFlick.width
          spacing: 6

          Repeater {
            model: PowerController.inhibitors

            Rectangle {
              required property var modelData

              width: inhibitColumn.width
              height: inhibitText.implicitHeight + 12
              radius: 8
              color: Theme.bgSurface
              border.color: Theme.bgBorder
              border.width: 1

              Column {
                id: inhibitText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 2

                Text {
                  width: parent.width
                  text: {
                    const who = modelData.who || "Unknown";
                    const comm = modelData.comm || "";
                    if (comm !== "" && comm !== who)
                      return who + " (" + comm + ")";
                    return who;
                  }
                  color: Theme.textPrimary
                  font.pixelSize: ThemeEngine.fontSizeSm
                  font.family: ThemeEngine.fontFamily
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: (modelData.why || "") !== ""
                  text: modelData.why || ""
                  color: Theme.textMuted
                  font.pixelSize: ThemeEngine.fontSizeSm
                  font.family: ThemeEngine.fontFamily
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        Rectangle {
          width: cancelLabel.implicitWidth + 20
          height: 32
          radius: 8
          color: cancelArea.containsMouse ? Theme.bgSelected : Theme.bgSurface
          border.color: Theme.bgBorder
          border.width: 1

          Text {
            id: cancelLabel
            anchors.centerIn: parent
            text: "Cancel"
            color: Theme.textPrimary
            font.pixelSize: ThemeEngine.fontSizeSm
            font.family: ThemeEngine.fontFamily
          }

          MouseArea {
            id: cancelArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: "Cancel"
            onClicked: PowerController.cancel()
          }
        }

        Rectangle {
          width: confirmLabel.implicitWidth + 20
          height: 32
          radius: 8
          color: confirmArea.containsMouse
            ? Theme.bgSelected
            : (PowerController.pendingAction === "shutdown" ? Theme.accentRed : Theme.accentPrimary)

          Text {
            id: confirmLabel
            anchors.centerIn: parent
            text: PowerController.pendingLabel
            color: Theme.bgBase
            font.pixelSize: ThemeEngine.fontSizeSm
            font.family: ThemeEngine.fontFamily
            font.bold: true
          }

          MouseArea {
            id: confirmArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: PowerController.pendingLabel
            onClicked: PowerController.confirm()
          }
        }
      }
    }
  }
}
