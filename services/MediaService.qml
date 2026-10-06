pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root

    // Active player selection: prefers playing player or first valid
    readonly property var players: {
        const list = Mpris.players ? Mpris.players.values : [];
        return list.filter(p => {
            if (!p) return false;
            const id = (p.identity || "").toLowerCase();
            const title = (p.trackTitle || "").toLowerCase();
            const artist = (p.trackArtist || "").toLowerCase();
            
            const isSpotifyApp = id.includes("spotify");
            const isBrowser = id.includes("brave") || id.includes("chrome") || id.includes("firefox");
            const art = (p.trackArtUrl || "").toLowerCase();
            // Navegadores no envían el dominio en MPRIS (ej. artUrl es un archivo /tmp/ local).
            // Por lo que permitiremos todo el audio del navegador para que funcione.
            return isSpotifyApp || isBrowser;
        });
    }
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
    readonly property bool isSpotify: activePlayer ? ((activePlayer.identity || "").toLowerCase().includes("spotify")) : false

    readonly property string rawTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string rawArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string rawAlbum: activePlayer ? (activePlayer.trackAlbum || "") : ""
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
    
    property real progress: 0.0
    property real lastPosition: 0.0
    property real lastLength: 0.0

    property var _progressTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (root.activePlayer && root.activePlayer.length > 0) {
                // Read directly from object to bypass missing notify signals
                const pos = root.activePlayer.position || 0;
                const len = root.activePlayer.length || 0;
                root.progress = Math.max(0.0, Math.min(1.0, pos / len));
                root.lastPosition = pos;
                root.lastLength = len;
            } else {
                root.progress = 0.0;
            }
        }
    }


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
