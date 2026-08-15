pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> playerList: Mpris.players.values
    property var _lastPlayerList: playerList
    function getPlayerIds() {
        return playerList.filter(Boolean).map((player) => player.dbusName);
    }
    readonly property int playingCount: playerList.map((player) => player.isPlaying).filter(Boolean).length
    property list<string> activeOrder: getPlayerIds()
    property int activeId: 0 // Selects last playing unless manually changed
    readonly property MprisPlayer activePlayer: playerList.find((player) => player.dbusName === activeOrder[activeId])

    function updateActiveOrder() {
        const added = getPlayerIds()
            .filter((id) => !activeOrder.includes(id));
        const modified = getPlayerIds()
            .filter((id) => !added.includes(id))
            .filter((id) =>
                _lastPlayerList.find((p) => p.dbusName === id)?.isPlaying
                    !== playerList.find((p) => p.dbusName === id).isPlaying)

        // New players, players that changed their playing status, old order
        const newActiveOrder = [...new Set([...added, ...modified, ...activeOrder])]
            .filter((id) => getPlayerIds().includes(id)); // Remove outdated ids

        if (newActiveOrder.length !== activeOrder.length || newActiveOrder.some((id, idx) => id !== activeOrder[idx])) {
            activeId = 0;
        }

        activeOrder = newActiveOrder;

        _lastPlayerList = playerList
            .filter(Boolean)
            .map(({ dbusName, isPlaying }) => ({ dbusName, isPlaying }));
    }

    onPlayingCountChanged: { activeId = 0; updateActiveOrder() }
    onPlayerListChanged: { activeId = 0; updateActiveOrder() }

    function handleTogglePlayPause() {
        if (!activePlayer?.canTogglePlaying) return;
        activePlayer.togglePlaying();
    }
    function handlePlayPreviousTrack() {
        if (!activePlayer?.canGoNext) return;
        activePlayer.next();
    }
    function handlePlayNextTrack() {
        if (!activePlayer?.canGoPrevious) return;
        activePlayer.previous();
    }
    function handleSwitchToNextPlayer() {
        if (!playerList.length || activeId >= playerList.length - 1) activeId = 0;
        else activeId += 1;
    }

    IpcHandler {
        target: 'media'
        function togglePlayPause() { handleTogglePlayPause() }
        function playPreviousTrack() { handlePlayPreviousTrack() }
        function playNextTrack() { handlePlayNextTrack() }
        function nextPlayer() { handleSwitchToNextPlayer() }
    }
}
