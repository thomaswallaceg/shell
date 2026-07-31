import QtQuick

// MouseArea that turns high-res wheel/trackpad input into discrete up/down
// steps. Mouse notches use mouseWheelThreshold (120 ≈ one notch); trackpads
// (pixelDelta or scroll phases) use the higher trackpadWheelThreshold.
MouseArea {
  id: root

  property int mouseWheelThreshold: 120
  property int trackpadWheelThreshold: 240
  property real wheelAccum: 0

  signal stepped(bool up)

  cursorShape: Qt.PointingHandCursor

  onWheel: (wheel) => {
    if (wheel.phase === Qt.ScrollEnd || wheel.phase === Qt.ScrollMomentum) {
      wheelAccum = 0;
      return;
    }
    if (wheel.phase === Qt.ScrollBegin)
      wheelAccum = 0;
    const dy = wheel.angleDelta.y || wheel.pixelDelta.y;
    if (dy === 0) return;
    const threshold = (wheel.phase !== Qt.NoScrollPhase || wheel.pixelDelta.y !== 0)
      ? trackpadWheelThreshold
      : mouseWheelThreshold;
    wheelAccum += dy;
    while (Math.abs(wheelAccum) >= threshold) {
      const up = wheelAccum > 0;
      wheelAccum -= up ? threshold : -threshold;
      root.stepped(up);
    }
  }
}
