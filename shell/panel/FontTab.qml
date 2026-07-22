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
        for (var i = 0; i < filteredFonts.length; i++) {
            if (filteredFonts[i].name === ThemeEngine.savedFontFamily) {
                idx = i;
                break;
            }
        }
        panelTab.selectedIndex = idx;
        panelTab.positionAt(idx, ListView.Center);
    }

    function clearPreview() {
        ThemeEngine.previewFontFamily = "";
    }

    property var filteredFonts: {
        var query = panelTab.searchText.trim().toLowerCase();
        var fonts = Qt.fontFamilies();
        var result = [];
        for (var i = 0; i < fonts.length; i++) {
            var family = fonts[i];
            if (query === "" || family.toLowerCase().indexOf(query) >= 0) {
                result.push({
                    id: "__font__" + family,
                    name: family
                });
            }
        }
        return result;
    }

    Connections {
        target: panelTab
        function onSelectedIndexChanged() {
            if (!root.active) return;
            const idx = panelTab.selectedIndex;
            if (idx < 0 || idx >= root.filteredFonts.length) return;
            ThemeEngine.previewFontFamily = root.filteredFonts[idx].name;
        }
    }

    ShellPanelTab {
        id: panelTab
        anchors.fill: parent

        searchPlaceholder: "Search fonts..."
        searchAccessibleName: "Search fonts"
        selectByMouse: true

        model: root.filteredFonts
        emptyText: "No fonts found"
        subtitleText: {
            const n = root.filteredFonts.length;
            return n + " font" + (n !== 1 ? "s" : "") + " — " + ThemeEngine.fontFamily;
        }

        hints: [
            { key: "↑↓", label: "navigate" },
            { key: "⏎", label: "select" },
            { key: "esc", label: "close" }
        ]

        onCloseRequested: root.closeRequested()
        onActivated: {
            if (root.filteredFonts.length > 0) {
                ThemeEngine.previewFontFamily = "";
                ThemeEngine.setFontFamily(root.filteredFonts[panelTab.selectedIndex].name);
                root.closeRequested();
            }
        }

        delegate: PanelListItem {
            required property var modelData
            required property int index

            selectedIndex: panelTab.selectedIndex

            onClicked: {
                ThemeEngine.previewFontFamily = "";
                ThemeEngine.setFontFamily(modelData.name);
                root.closeRequested();
            }
            onHovered: panelTab.selectedIndex = index

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: modelData.name
                    color: selectedIndex === index ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: ThemeEngine.fontSizeLg
                    font.family: modelData.name
                    font.bold: selectedIndex === index
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    text: "✓"
                    color: Theme.accentGreen
                    font.pixelSize: ThemeEngine.fontSizeLg
                    font.family: ThemeEngine.fontFamily
                    visible: ThemeEngine.savedFontFamily === modelData.name
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }
}
