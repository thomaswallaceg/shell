import QtQuick
import "../common/theme-switcher"

Rectangle {
    id: root

    property int selectedIndex: -1
    property bool hoverHighlight: true

    signal clicked()
    signal hovered()

    width: ListView.view ? ListView.view.width : 0
    height: 44
    radius: 8
    color: hoverHighlight && hoverArea.containsMouse && index !== selectedIndex
        ? Theme.bgHover
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    default property alias content: contentSlot.data

    Item {
        id: contentSlot
        anchors.fill: parent
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // positionChanged (not entered): recreating delegates under a
        // stationary cursor after a filter must not steal the selection
        // that onTextEdited just reset to 0.
        onPositionChanged: root.hovered()
    }
}
