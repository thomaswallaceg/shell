import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.common.theme

Scope {
    id: root

    property string currentTab: "launcher"

    readonly property var tabs: {
        "launcher": { title: "Applications", icon: "󰀻" },
        "theme": { title: "Themes", icon: "󰏘" },
        "font": { title: "Fonts", icon: "󰛖" }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleTab("launcher"); }
    }

    IpcHandler {
        target: "theme"
        function toggle(): void { root.toggleTab("theme"); }
    }

    IpcHandler {
        target: "font"
        function toggle(): void { root.toggleTab("font"); }
    }

    function closePanel() {
        themeTab.clearPreview();
        fontTab.clearPreview();
        shellPanel.visible = false;
    }

    function activateTab(tab) {
        // Reset the incoming tab before showing it so the header and list
        // swap in the same frame.
        if (tab === "launcher") launcherTab.prepare();
        else if (tab === "theme") themeTab.prepare();
        else if (tab === "font") fontTab.prepare();
        root.currentTab = tab;
    }

    function toggleTab(tab) {
        if (shellPanel.visible && root.currentTab === tab) {
            closePanel();
            return;
        }
        if (!shellPanel.visible) {
            shellPanel.visible = true;
        }
        activateTab(tab);
    }

    onCurrentTabChanged: {
        if (!shellPanel.visible) return;

        if (currentTab !== "theme") themeTab.clearPreview();
        if (currentTab !== "font") fontTab.clearPreview();
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
                        text: root.tabs[root.currentTab].title
                        color: Theme.textPrimary
                        font.pixelSize: ThemeEngine.fontSizeLg
                        font.family: ThemeEngine.fontFamily
                        font.bold: true

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.tabs[root.currentTab].icon
                        color: Theme.textPrimary
                        font.pixelSize: ThemeEngine.fontSizeIcon
                        font.family: ThemeEngine.fontFamily
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: Object.keys(root.tabs).indexOf(root.currentTab)

                    LauncherTab {
                        id: launcherTab
                        onCloseRequested: root.closePanel()
                    }

                    ThemeTab {
                        id: themeTab
                        active: shellPanel.visible && root.currentTab === "theme"
                        onCloseRequested: root.closePanel()
                    }

                    FontTab {
                        id: fontTab
                        active: shellPanel.visible && root.currentTab === "font"
                        onCloseRequested: root.closePanel()
                    }
                }
            }
        }
    }
}
