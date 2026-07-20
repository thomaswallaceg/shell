import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../services"
import "../common/theme-switcher"

Scope {
    id: root

    IpcHandler {
        target: "notifications"

        function dismiss_all(): void {
            NotificationService.dismissAll();
        }

        function dnd_toggle(): void {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notifWindow
            required property var modelData
            screen: modelData

            visible: NotificationService.notifications.length > 0 && modelData === Displays.smallestScreen
            focusable: false
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-notifications"

            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                right: true
            }

            // The bar is only ever permanently shown in multi-monitor mode; in
            // single-monitor mode it's hidden by default (hover/peek reveal),
            // so there's no need to reserve space for it — we don't track its
            // live reveal state, so if it's peeked while a notification is up
            // they can just overlap in that case.
            readonly property int barOffset: Displays.singleMonitor ? 0 : ThemeEngine.barHeight

            implicitWidth: 380
            implicitHeight: notifColumn.implicitHeight + notifWindow.barOffset + 20

            ColumnLayout {
                id: notifColumn
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: notifWindow.barOffset + 10
                anchors.rightMargin: 10
                width: 360
                spacing: 8

                Repeater {
                    model: ScriptModel {
                        values: NotificationService.notifications
                        objectProp: "seqId"
                    }

                    Rectangle {
                        id: notifCard
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: cardContent.implicitHeight + 24
                        radius: 12
                        color: Theme.bgBase
                        border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.urgencyCritical :
                                      modelData.urgency === NotificationUrgency.Low     ? Theme.urgencyLow     : Theme.bgBorder
                        border.width: 1
                        clip: true

                        Accessible.role: Accessible.StaticText
                        Accessible.name: (modelData.urgency === NotificationUrgency.Critical ? "[Critical] " :
                                         modelData.urgency === NotificationUrgency.Low       ? "[Low] "      : "") +
                                         (modelData.appName || "Notification") + ": " + modelData.summary

                        HoverHandler {
                            id: cardHover
                            onHoveredChanged: notifCard.modelData.hovered = hovered
                        }

                        NumberAnimation on opacity {
                            id: entryAnim
                            from: 0; to: 1
                            duration: 200
                            easing.type: Easing.OutCubic
                            running: false
                        }
                        Component.onCompleted: entryAnim.start()

                        Rectangle {
                            width: 3
                            height: parent.height - 16
                            radius: 2
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: notifCard.modelData.urgency === NotificationUrgency.Critical ? Theme.urgencyCritical :
                                   notifCard.modelData.urgency === NotificationUrgency.Low      ? Theme.urgencyLow      : Theme.urgencyNormal
                        }

                        ColumnLayout {
                            id: cardContent
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 12
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Item {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter

                                    IconImage {
                                        anchors.centerIn: parent
                                        source: Quickshell.iconPath(notifCard.modelData.appIcon, true)
                                        implicitSize: 16
                                        visible: notifCard.modelData.appIcon !== ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: notifCard.modelData.appIcon === ""
                                        text: {
                                            const name = notifCard.modelData.appName.toLowerCase();
                                            if (notifCard.modelData.urgency === NotificationUrgency.Critical) return "󰀦";
                                            if (name.includes("discord"))  return "󰙯";
                                            if (name.includes("firefox"))  return "󰈹";
                                            if (name.includes("chrome"))   return "";
                                            if (name.includes("telegram")) return "";
                                            if (name.includes("spotify"))  return "󰓇";
                                            if (name.includes("terminal") || name.includes("kitty") || name.includes("alacritty")) return "";
                                            return "󰂚";
                                        }
                                        color: notifCard.modelData.urgency === NotificationUrgency.Critical
                                               ? Theme.urgencyCritical : Theme.urgencyNormal
                                        font.pixelSize: ThemeEngine.fontSizeLg
                                        font.family: ThemeEngine.fontFamily
                                    }
                                }

                                Text {
                                    text: notifCard.modelData.appName || "Notification"
                                    color: Theme.textMuted
                                    font.pixelSize: ThemeEngine.fontSizeSm
                                    font.family: ThemeEngine.fontFamily
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: closeHover.containsMouse ? Theme.bgBorder : "transparent"
                                    Layout.alignment: Qt.AlignVCenter
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Dismiss notification"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: closeHover.containsMouse ? Theme.accentRed : Theme.textMuted
                                        font.pixelSize: ThemeEngine.fontSizeLg
                                        font.family: ThemeEngine.fontFamily
                                    }

                                    MouseArea {
                                        id: closeHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notifCard.modelData.dismiss()
                                    }
                                }
                            }

                            Text {
                                text: notifCard.modelData.summary
                                color: Theme.textPrimary
                                font.pixelSize: ThemeEngine.fontSizeLg
                                font.family: ThemeEngine.fontFamily
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text !== ""
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: notifCard.modelData.body !== "" || notifCard.modelData.image !== ""

                                Text {
                                    text: notifCard.modelData.body
                                    color: Theme.textSecondary
                                    font.pixelSize: ThemeEngine.fontSizeLg
                                    font.family: ThemeEngine.fontFamily
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    textFormat: Text.PlainText
                                }

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: 4
                                    color: "transparent"
                                    clip: true
                                    visible: notifCard.modelData.image !== ""

                                    Image {
                                        anchors.fill: parent
                                        source: notifCard.modelData.image
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 24
                                        sourceSize.height: 24
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: notifCard.modelData.actions.length > 0

                                Repeater {
                                    model: notifCard.modelData.actions

                                    Rectangle {
                                        id: actionBtn
                                        required property var modelData

                                        Layout.preferredHeight: 26
                                        Layout.preferredWidth: actionText.width + 16
                                        radius: 6
                                        color: actionHover.containsMouse ? Theme.bgBorder : Theme.bgSurface

                                        Behavior on color {
                                            ColorAnimation { duration: 100 }
                                        }

                                        Accessible.role: Accessible.Button
                                        Accessible.name: actionBtn.modelData.text || ""

                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: actionBtn.modelData.text || ""
                                            color: Theme.accentPrimary
                                            font.pixelSize: ThemeEngine.fontSizeSm
                                            font.family: ThemeEngine.fontFamily
                                        }

                                        MouseArea {
                                            id: actionHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notifCard.modelData.invokeAction(actionBtn.modelData.identifier)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                radius: 1
                                color: Theme.bgSurface
                                Layout.topMargin: 2
                                visible: notifCard.modelData.urgency !== NotificationUrgency.Critical

                                Rectangle {
                                    id: progressBar
                                    height: parent.height
                                    width: parent.width
                                    radius: 1
                                    color: notifCard.modelData.urgency === NotificationUrgency.Critical
                                           ? Theme.urgencyCritical : Theme.urgencyNormal
                                    opacity: 0.6

                                    SequentialAnimation {
                                        running: notifCard.modelData.urgency !== NotificationUrgency.Critical
                                        PauseAnimation { duration: 50 }
                                        NumberAnimation {
                                            target: progressBar
                                            property: "width"
                                            to: 0
                                            duration: notifCard.modelData.expireTimeout > 0
                                                      ? notifCard.modelData.expireTimeout
                                                      : notifCard.modelData.defaultTimeout  // no * 1000: matches the timer — Quickshell passes raw D-Bus ms
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: 30
                            z: -1
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    notifCard.modelData.dismiss();
                                else
                                    notifCard.modelData.invokeDefaultAction();
                            }
                        }
                    }
                }
            }
        }
    }
}
