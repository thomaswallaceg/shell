import QtQuick
import Quickshell.Services.Mpris
import "../../common/theme-switcher"

BarPill {
  id: root

  property var activePlayer: {
    const players = Mpris.players.values;
    if (!players || players.length === 0) return null;
    for (const p of players) {
      if (p.playbackState === MprisPlaybackState.Playing) return p;
    }
    return players[0];
  }

  implicitWidth: nowPlayingContent.width + 16
  visible: activePlayer !== null

  Accessible.role: Accessible.Button
  Accessible.name: {
    if (!activePlayer) return "No media";
    const artist = activePlayer.trackArtist || "";
    const title = activePlayer.trackTitle || "";
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
      text: root.activePlayer && root.activePlayer.isPlaying ? "󰐊" : "󰏤"
      color: Theme.accentPrimary
      font.pixelSize: ThemeEngine.fontSizeIcon
      font.family: ThemeEngine.fontFamily
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (!root.activePlayer) return "";
        const artist = root.activePlayer.trackArtist || "";
        const title = root.activePlayer.trackTitle || "";
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
    onClicked: root.activePlayer.togglePlaying()
  }
}
