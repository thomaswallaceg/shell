import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.panel

Item {
    id: root

    property bool active: false

    signal closeRequested()

    property var filteredFonts: []
    property bool hasPropoFonts: true
    property bool hasNerdFonts: true

    onActiveChanged: {
        if (!active) {
            clearPreview();
            return;
        }
        applyPreview();
    }

    function isNerdFont(family) {
        return /Nerd[\s_-]?Font|[\s_-]NF(P|M)?\b|NFP\b|NFM\b/i.test(family);
    }

    function isPropoNerdFont(family) {
        return (/Nerd[\s_-]?Font[\s_-]?Propo|NFP\b|NFP$|[\s_-]Propo\b/i.test(family)) && root.isNerdFont(family);
    }

    function updateFilteredFonts() {
        const query = panelTab.searchText.trim().toLowerCase();
        const allFonts = Qt.fontFamilies();

        // 1. Prefer Propo Nerd Fonts (*Nerd Font Propo*, *NFP*)
        // 2. If none installed, fall back to any Nerd Font (*Nerd Font*, *NF*)
        // 3. If no Nerd Fonts installed, fall back to all system fonts
        const propo = allFonts.filter(f => root.isPropoNerdFont(f));
        const nerd = allFonts.filter(f => root.isNerdFont(f));

        root.hasPropoFonts = propo.length > 0;
        root.hasNerdFonts = nerd.length > 0;

        const baseList = root.hasPropoFonts ? propo : (root.hasNerdFonts ? nerd : allFonts);

        const result = [];
        for (let i = 0; i < baseList.length; i++) {
            const family = baseList[i];
            if (query === "" || family.toLowerCase().indexOf(query) >= 0) {
                result.push({
                    id: "__font__" + family,
                    name: family,
                    isPropo: root.isPropoNerdFont(family)
                });
            }
        }
        root.filteredFonts = result;
    }

    function prepare() {
        panelTab.clearSearch();
        let idx = 0;
        for (let i = 0; i < filteredFonts.length; i++) {
            if (filteredFonts[i].name === ThemeEngine.savedFontFamily) {
                idx = i;
                break;
            }
        }
        panelTab.selectedIndex = idx;
        panelTab.positionAt(idx, ListView.Top);
    }

    function clearPreview() {
        ThemeEngine.previewFontFamily = "";
    }

    function applyPreview() {
        const idx = panelTab.selectedIndex;
        if (idx < 0 || idx >= root.filteredFonts.length) return;
        ThemeEngine.previewFontFamily = root.filteredFonts[idx].name;
    }

    Connections {
        target: panelTab
        function onSearchTextChanged() {
            root.updateFilteredFonts();
        }
    }

    Connections {
        target: panelTab
        function onSelectedIndexChanged() {
            if (root.active)
                root.applyPreview();
        }
    }

    Component.onCompleted: root.updateFilteredFonts()

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
        warningText: {
            if (!root.hasPropoFonts && root.hasNerdFonts)
                return "No Propo Nerd Fonts found — showing standard Nerd Fonts.";
            if (!root.hasPropoFonts && !root.hasNerdFonts)
                return "No Nerd Fonts detected on system — interface icons may not display correctly.";
            return "";
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
