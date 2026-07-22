import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common/theme-switcher"

Scope {
    id: root

    property int currentTab: 0

    readonly property var tabs: [
        { title: "Applications", icon: "󰀻", next: 1 },
        { title: "Themes", icon: "󰏘", next: 2 },
        { title: "Fonts", icon: "󰛖", next: 0 }
    ]

    readonly property string panelTitle: tabs[currentTab].title
    readonly property string switchTabIcon: tabs[tabs[currentTab].next].icon
    readonly property string switchTabLabel: tabs[tabs[currentTab].next].title

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleTab(0); }
    }

    IpcHandler {
        target: "theme"
        function toggle(): void { root.toggleTab(1); }
    }

    IpcHandler {
        target: "font"
        function toggle(): void { root.toggleTab(2); }
    }

    function closePanel() {
        themeTab.clearPreview();
        fontTab.clearPreview();
        shellPanel.visible = false;
    }

    function activateTab(tab) {
        root.currentTab = tab;
        if (tab === 0)
            launcherTab.prepare();
        else if (tab === 1)
            themeTab.prepare();
        else
            fontTab.prepare();
    }

    function switchTab() {
        activateTab(tabs[currentTab].next);
    }

    function toggleTab(tab) {
        if (shellPanel.visible && root.currentTab === tab) {
            closePanel();
            return;
        }
        shellPanel.visible = true;
        activateTab(tab);
    }

    onCurrentTabChanged: {
        if (!shellPanel.visible)
            return;
        if (currentTab !== 1)
            themeTab.clearPreview();
        if (currentTab !== 2)
            fontTab.clearPreview();
    }

    PanelWindow {
        id: shellPanel
        visible: false
        focusable: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-panel"

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()

            Rectangle {
                anchors.fill: parent
                color: Theme.bgOverlay
            }
        }

        Rectangle {
            id: panelBox
            anchors.centerIn: parent
            width: 620
            height: 520
            radius: 16
            color: Theme.bgBase
            border.color: Theme.bgBorder
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.panelTitle
                        color: Theme.textPrimary
                        font.pixelSize: ThemeEngine.fontSizeLg
                        font.family: ThemeEngine.fontFamily
                        font.bold: true

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: tabSwitchArea.containsMouse ? Theme.bgSelected : Theme.bgSurface
                        border.color: Theme.bgBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.switchTabIcon
                            color: Theme.textSecondary
                            font.pixelSize: ThemeEngine.fontSizeIcon
                            font.family: ThemeEngine.fontFamily

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: tabSwitchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: "Switch to " + root.switchTabLabel
                            onClicked: root.switchTab()
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTab

                    LauncherTab {
                        id: launcherTab
                        onCloseRequested: root.closePanel()
                    }

                    ThemeTab {
                        id: themeTab
                        active: root.currentTab === 1 && shellPanel.visible
                        onCloseRequested: root.closePanel()
                    }

                    FontTab {
                        id: fontTab
                        active: root.currentTab === 2 && shellPanel.visible
                        onCloseRequested: root.closePanel()
                    }
                }
            }
        }
    }
}
