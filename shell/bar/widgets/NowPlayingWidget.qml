import QtQuick
// import Quickshell.Services.Mpris
import qs.common.theme
import qs.common.widgets
import qs.services

BarPill {
  id: root

  visible: Mpris.activePlayer
  implicitWidth: nowPlayingContent.width + 16

  Accessible.role: Accessible.Button
  Accessible.name: {
    if (!Mpris.activePlayer) return "No media";
    const artist = Mpris.activePlayer.trackArtist || "";
    const title = Mpris.activePlayer.trackTitle || "";
    return "Now playing: " + (artist ? artist + " - " : "") + title;
  }

  Row {
    id: nowPlayingContent
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: 8
    spacing: 6

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: (!!Mpris.activePlayer && Mpris.activePlayer.isPlaying) ? "󰏤" : "󰐊"
      color: Theme.accentPrimary
      font.pixelSize: ThemeEngine.fontSizeIcon
      font.family: ThemeEngine.fontFamily
      width: 8
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (!Mpris.activePlayer) return "";
        const artist = Mpris.activePlayer.trackArtist || "";
        const title = Mpris.activePlayer.trackTitle || "";
        return artist ? artist + " - " + title : title;
      }
      color: Theme.textPrimary
      font.pixelSize: ThemeEngine.fontSizeLg
      font.family: ThemeEngine.fontFamily
      elide: Text.ElideRight
      width: Math.min(implicitWidth, 200)
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Mpris.handleTogglePlayPause()
  }
}
