import QtQuick
import QtQuick.Layouts
import "../common/theme-switcher"

Item {
    id: root

    property bool active: false

    signal closeRequested()

    onActiveChanged: {
        if (!active)
            clearPreview();
    }

    function prepare() {
        panelTab.clearSearch();
        var idx = 0;
        for (var i = 0; i < filteredThemes.length; i++) {
            if (filteredThemes[i].id === ThemeEngine.currentId) {
                idx = i;
                break;
            }
        }
        panelTab.selectedIndex = idx;
        panelTab.positionAt(idx, ListView.Center);
    }

    function clearPreview() {
        ThemeEngine.previewId = "";
    }

    property var filteredThemes: {
        var query = panelTab.searchText.toLowerCase();
        var result = [];
        for (var i = 0; i < ThemeEngine.themes.length; i++) {
            var t = ThemeEngine.themes[i];
            if (query === "" || t.name.toLowerCase().indexOf(query) >= 0 || t.family.toLowerCase().indexOf(query) >= 0) {
                result.push({ data: t, id: t.id, family: t.family });
            }
        }
        return result;
    }

    // Live preview follows the selected row while the tab is visible.
    Connections {
        target: panelTab
        function onSelectedIndexChanged() {
            if (!root.active) return;
            const idx = panelTab.selectedIndex;
            if (idx < 0 || idx >= root.filteredThemes.length) return;
            ThemeEngine.previewId = root.filteredThemes[idx].id;
        }
    }

    ShellPanelTab {
        id: panelTab
        anchors.fill: parent

        searchPlaceholder: "Search themes..."
        searchAccessibleName: "Search themes"
        selectByMouse: true

        model: root.filteredThemes
        sectionProperty: "family"
        emptyText: "No themes found"
        subtitleText: panelTab.searchText !== ""
            ? root.filteredThemes.length + " of " + ThemeEngine.count + " themes"
            : ThemeEngine.count + " themes — " + ThemeEngine.currentFamily + " " + ThemeEngine.currentName

        hints: [
            { key: "↑↓", label: "navigate" },
            { key: "⏎", label: "select" },
            { key: "esc", label: "close" }
        ]

        onCloseRequested: root.closeRequested()
        onActivated: {
            if (root.filteredThemes.length > 0) {
                ThemeEngine.previewId = "";
                ThemeEngine.setTheme(root.filteredThemes[panelTab.selectedIndex].id);
                root.closeRequested();
            }
        }

        delegate: PanelListItem {
            required property var modelData
            required property int index

            selectedIndex: panelTab.selectedIndex

            onClicked: {
                ThemeEngine.previewId = "";
                ThemeEngine.setTheme(modelData.id);
                root.closeRequested();
            }
            onHovered: panelTab.selectedIndex = index

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: modelData.data.name
                    color: selectedIndex === index ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: ThemeEngine.fontSizeLg
                    font.family: ThemeEngine.fontFamily
                    font.bold: selectedIndex === index
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: [
                            modelData.data.bgBase,
                            modelData.data.accentPrimary,
                            modelData.data.accentGreen,
                            modelData.data.accentOrange,
                            modelData.data.accentRed
                        ]

                        Rectangle {
                            required property var modelData
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData
                            border.color: Theme.bgBorder
                            border.width: 1
                        }
                    }
                }

                Text {
                    text: "✓"
                    color: Theme.accentGreen
                    font.pixelSize: ThemeEngine.fontSizeLg
                    font.family: ThemeEngine.fontFamily
                    visible: ThemeEngine.currentId === modelData.id
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }
}
