import QtQuick
import qs.common.theme

// Horizontally-scrolling ("marquee") text for content that doesn't fit a
// fixed-width bar pill (e.g. NowPlayingWidget's track title), instead of
// eliding it. Only animates when the text actually overflows maxWidth; sits
// still otherwise. A second copy of the text trails the first by `gap` so
// the loop reads as continuous rather than a jump-cut back to the start.
Item {
  id: root

  property alias text: label.text
  property alias font: label.font
  property color color: Theme.textPrimary
  property real maxWidth: 200
  // Pixels/second scroll speed.
  property real speed: 30
  // Pause at the start of each pass before scrolling.
  property int pauseDuration: 1500
  property real gap: 24

  readonly property bool overflowing: label.implicitWidth > maxWidth

  clip: true
  implicitWidth: Math.min(label.implicitWidth, maxWidth)
  implicitHeight: label.implicitHeight

  onOverflowingChanged: if (!overflowing)
    scrollRow.x = 0;

  Row {
    id: scrollRow
    spacing: root.gap

    Text {
      id: label
      color: root.color
    }

    Text {
      text: root.overflowing ? label.text : ""
      color: root.color
      font: label.font
    }
  }

  SequentialAnimation {
    running: root.overflowing && root.visible
    loops: Animation.Infinite

    PauseAnimation { duration: root.pauseDuration }
    NumberAnimation {
      target: scrollRow
      property: "x"
      from: 0
      to: -(label.implicitWidth + root.gap)
      duration: (label.implicitWidth + root.gap) / root.speed * 1000
      easing.type: Easing.Linear
    }
  }
}
