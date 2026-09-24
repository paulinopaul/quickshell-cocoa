pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root

    // Active player selection: prefers playing player or first valid
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property MprisPlayer activePlayer: {
        if (!players || players.length === 0) return null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) {
                return players[i];
            }
        }
        return players[0];
    }

    readonly property bool hasMedia: activePlayer !== null
    readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false

    readonly property string rawTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string rawArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""

    readonly property string displayTitle: {
        if (!hasMedia) return "No Media";
        const t = rawTitle.trim();
        const a = rawArtist.trim();
        if (t && a) return `${a} - ${t}`;
        return t || a || "Playing Media";
    }

    readonly property real position: activePlayer ? (activePlayer.position || 0) : 0
    readonly property real length: activePlayer ? (activePlayer.length || 0) : 0
    readonly property real progress: (length > 0) ? Math.max(0.0, Math.min(1.0, position / length)) : 0.0

    function playPause(): void {
        if (activePlayer) {
            activePlayer.togglePlaying();
        }
    }

    function next(): void {
        if (activePlayer && activePlayer.canGoNext) {
            activePlayer.next();
        }
    }

    function previous(): void {
        if (activePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous();
        }
    }
}
