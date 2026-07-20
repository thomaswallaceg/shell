import QtQuick
import QtQuick.Layouts
import "../common/theme-switcher"
import "../common/panel"

// Shared layout for a panel tab: search bar, result-count subtitle, list,
// and key hints footer. Navigation (arrow keys / count clamping) lives here
// since it's identical between tabs; tab-specific data (model, delegate,
// activation behavior) is supplied by the caller.
Item {
    id: root

    property alias searchText: searchInput.text
    property string searchPlaceholder: "Search..."
    property string searchAccessibleName: "Search"
    property bool selectByMouse: false
    property bool acceptTab: false
    // When true, an empty search resets selection to -1 (nothing highlighted)
    // instead of 0 — used by the launcher, where an empty query shows the
    // full unfiltered app list rather than "search results".
    property bool clearSelectionOnEmpty: false

    property int selectedIndex: 0
    property var model
    property alias delegate: resultsList.delegate
    property string sectionProperty: ""
    property string emptyText: ""
    property string subtitleText: ""
    property var hints: []

    signal activated(int modifiers)
    signal closeRequested()

    function clearSearch() {
        searchInput.clear();
    }

    function positionAt(index, mode) {
        resultsList.positionAt(index, mode);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PanelSearchInput {
            id: searchInput
            placeholder: root.searchPlaceholder
            accessibleName: root.searchAccessibleName
            selectByMouse: root.selectByMouse
            acceptTab: root.acceptTab

            onTextEdited: text => {
                root.selectedIndex = (root.clearSelectionOnEmpty && text === "") ? -1 : 0;
            }
            onEscapePressed: root.closeRequested()
            onNavigate: direction => {
                root.selectedIndex = direction < 0
                    ? Math.max(root.selectedIndex - 1, 0)
                    : Math.min(root.selectedIndex + 1, resultsList.count - 1);
                resultsList.positionAt(root.selectedIndex, ListView.Contain);
            }
            onActivated: modifiers => root.activated(modifiers)
        }

        PanelSubtitle {
            text: root.subtitleText
        }

        PanelList {
            id: resultsList
            model: root.model
            selectedIndex: root.selectedIndex
            sectionProperty: root.sectionProperty
            emptyText: root.emptyText
            emptyVisible: searchInput.text !== ""
        }

        PanelKeyHints {
            hints: root.hints
        }
    }
}
