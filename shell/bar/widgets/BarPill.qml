import QtQuick
import "../../common/theme-switcher"

// Generic rounded "pill" chrome shared by every bar indicator — just the
// background shape. Callers provide their own content as children (typically
// a Row, sized via implicitWidth/width) exactly like a plain Rectangle, so
// any widget can use this for its background regardless of what it displays.
// See IconTextBarPill for the common icon+label case.
Rectangle {
  implicitHeight: 24
  radius: height / 2
  color: Theme.bgSurface
}
