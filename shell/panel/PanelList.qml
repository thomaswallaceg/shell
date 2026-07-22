import QtQuick
import QtQuick.Layouts
import "../common/theme-switcher"

ListView {
    id: root

    property int selectedIndex: -1
    property string emptyText: ""
    property bool emptyVisible: false
    property string sectionProperty: ""

    signal itemHovered(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 150
    highlightMoveVelocity: -1

    highlight: PanelListHighlight {
        visible: root.selectedIndex >= 0
    }

    // Don't bind currentIndex: selectedIndex — ListView writes currentIndex
    // itself when the model is filtered/diffed, which permanently breaks that
    // binding. Push the selection into currentIndex explicitly instead.
    // Re-assert on count changes *and* whenever ListView drifts afterward
    // (its post-diff adjustment can run after a callLater sync, e.g. when the
    // previously-current row is still in the filtered model and gets moved).
    function syncCurrentIndex() {
        if (currentIndex !== selectedIndex)
            currentIndex = selectedIndex;
    }

    onSelectedIndexChanged: syncCurrentIndex()
    onCountChanged: Qt.callLater(syncCurrentIndex)
    onCurrentIndexChanged: {
        if (currentIndex !== selectedIndex)
            Qt.callLater(syncCurrentIndex);
    }

    Component.onCompleted: applySections()
    onSectionPropertyChanged: applySections()

    function applySections() {
        if (sectionProperty !== "") {
            section.property = sectionProperty;
            section.delegate = sectionHeaderComponent;
        }
    }

    Component {
        id: sectionHeaderComponent
        PanelSectionHeader {}
    }

    Text {
        anchors.centerIn: parent
        text: root.emptyText
        color: Theme.textMuted
        font.pixelSize: ThemeEngine.fontSizeLg
        font.family: ThemeEngine.fontFamily
        visible: root.count === 0 && root.emptyVisible

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    function positionAt(index, mode) {
        positionViewAtIndex(index, mode);
    }
}
