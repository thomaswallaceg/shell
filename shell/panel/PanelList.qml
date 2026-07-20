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
    // callLater on count changes so we win over ListView's own post-update
    // currentIndex adjustment.
    function syncCurrentIndex() {
        currentIndex = selectedIndex;
    }

    onSelectedIndexChanged: syncCurrentIndex()
    onCountChanged: Qt.callLater(syncCurrentIndex)

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
