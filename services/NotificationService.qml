pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "."

// NotificationService: Singleton reactivo que gestiona el ciclo de vida,
// sanitización, extracción de paleta y supresión de notificaciones del sistema.
// Cumple con el principio de responsabilidad única (SOLID).

Item {
    id: root

    property bool hasActiveNotification: false
    property string currentAppName: ""
    property string currentSummary: ""
    property string currentBody: ""
    property string currentIcon: ""
    property string currentTime: ""
    property string formattedText: ""
    property bool centralPanelDetached: false
    property string gradientColor: "#7f99cc"
    property string asciiIcon: ""
    property bool isAgentOrTerminal: false
    property string agentName: ""

    // Soporte para paleta de colores de álbum y modo Spotify
    property var albumPalette: ["#1db954", "#1ed760", "#0f381e"]
    property bool isSpotifyTrack: false

    property var activeNotif: null

    Timer {
        id: dismissTimer
        interval: 4000
        repeat: false
        onTriggered: root.dismissCurrent()
    }

    onCentralPanelDetachedChanged: {
        if (root.centralPanelDetached && root.hasActiveNotification) {
            root.dismissCurrent();
        }
    }

    // Extractor asíncrono de paleta sin bloqueo del hilo UI
    property Process paletteProc: Process {
        id: paletteProc
        property string targetSource: ""
        command: targetSource !== "" ? ["python3", "/home/paul/.config/quickshell/cocoa/scripts/album_palette_extractor.py", targetSource] : ["true"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed && parsed.colors && parsed.colors.length === 3) {
                        root.albumPalette = parsed.colors;
                    }
                } catch (e) {}
            }
        }
    }

    function extractAlbumPalette(src): void {
        if (!src) return;
        paletteProc.running = false;
        paletteProc.targetSource = src;
        paletteProc.running = true;
    }

    // Sincronización reactiva con cambios de pista en Spotify vía MediaService
    Connections {
        target: MediaService
        function onArtUrlChanged() {
            if (MediaService.isSpotify && MediaService.isPlaying && MediaService.hasMedia) {
                root.triggerSpotifyTrackNotification();
            }
        }
        function onRawAlbumChanged() {
            if (MediaService.isSpotify && MediaService.isPlaying && MediaService.hasMedia) {
                root.triggerSpotifyTrackNotification();
            }
        }
    }

    function triggerSpotifyTrackNotification(): void {
        if (root.centralPanelDetached) return;
        if (!MediaService.isSpotify || !MediaService.hasMedia) return;

        let album = sanitizeText(MediaService.rawAlbum);
        let artist = sanitizeText(MediaService.rawArtist);
        let text = "";
        if (album && artist && album.toLowerCase() !== artist.toLowerCase()) {
            text = album + " - " + artist;
        } else if (album) {
            text = album;
        } else if (artist) {
            text = artist;
        } else {
            text = "Spotify";
        }

        // Evitar duplicación si ya está activa la misma pista
        if (root.hasActiveNotification && root.isSpotifyTrack && root.formattedText === text) {
            return;
        }

        root.isSpotifyTrack = true;
        root.isAgentOrTerminal = false;
        root.agentName = "";
        root.asciiIcon = "";
        root.currentAppName = "Spotify";
        root.currentIcon = "spotify";
        root.currentSummary = album;
        root.currentBody = artist;
        root.currentTime = Qt.formatDateTime(new Date(), "hh:mm");
        root.formattedText = text;
        root.hasActiveNotification = true;

        if (MediaService.artUrl) {
            root.extractAlbumPalette(MediaService.artUrl);
        }

        dismissTimer.stop();
        dismissTimer.interval = 4000;
        dismissTimer.start();
    }

    function sanitizeText(str): string {
        if (!str) return "";
        let s = ("" + str).replace(/<[^>]+>/g, " ");
        s = s.replace(/&amp;/g, "&")
             .replace(/&lt;/g, "<")
             .replace(/&gt;/g, ">")
             .replace(/&quot;/g, "\"")
             .replace(/&#39;/g, "'");
        s = s.replace(/\s+/g, " ").trim();
        return s;
    }

    function classifyNotification(appName, summary, body, desktopEntry): var {
        let app = (appName || "").toLowerCase().trim();
        let desk = (desktopEntry || "").toLowerCase().trim();
        let sum = (summary || "").toLowerCase().trim();
        let bod = (body || "").toLowerCase().trim();
        let combined = app + " " + desk + " " + sum + " " + bod;

        // Terminal check with word boundary for short identifiers like 'st'
        const terminals = ["kitty", "alacritty", "foot", "konsole", "wezterm", "gnome-terminal", "xterm", "bash", "zsh", "fish", "terminal", "urxvt", "tilix"];
        let isTerm = terminals.some(t => app.indexOf(t) !== -1 || desk.indexOf(t) !== -1);
        if (!isTerm && (/\bst\b/.test(app) || /\bst\b/.test(desk))) {
            isTerm = true;
        }

        // Agent check
        const agents = [
            { name: "Antigravity", regex: /\b(antigravity|agy|gemini)\b/, icon: "▲", color: "#8a63d2" },
            { name: "Claude", regex: /\b(claude|anthropic)\b/, icon: "✻", color: "#d97757" },
            { name: "ChatGPT", regex: /\b(chatgpt|openai|gpt)\b/, icon: "✳", color: "#10a37f" },
            { name: "Aider", regex: /\b(aider)\b/, icon: "⯌", color: "#3b82f6" },
            { name: "Cursor", regex: /\b(cursor)\b/, icon: "❯_", color: "#00b4d8" }
        ];

        for (let i = 0; i < agents.length; ++i) {
            if (agents[i].regex.test(combined)) {
                return {
                    isAgentOrTerminal: true,
                    agentName: agents[i].name,
                    asciiIcon: agents[i].icon,
                    color: agents[i].color
                };
            }
        }

        if (isTerm) {
            return {
                isAgentOrTerminal: true,
                agentName: "Terminal",
                asciiIcon: ">_",
                color: "#22c55e"
            };
        }

        const brands = {
            "spotify": "#1db954",
            "discord": "#5865f2",
            "firefox": "#ff7139",
            "telegram": "#24a1de",
            "steam": "#2a475e"
        };

        for (let b in brands) {
            if (app.indexOf(b) !== -1 || desk.indexOf(b) !== -1) {
                return {
                    isAgentOrTerminal: false,
                    agentName: "",
                    asciiIcon: "",
                    color: brands[b]
                };
            }
        }

        return {
            isAgentOrTerminal: false,
            agentName: "",
            asciiIcon: "",
            color: "#7f99cc"
        };
    }

    function handleNotification(notif): void {
        if (!notif) return;

        // Si el panel central está desacoplado, la notificación debe desaparecer/no mostrarse
        if (root.centralPanelDetached) {
            try { notif.dismiss(); } catch (e) {}
            return;
        }

        root.activeNotif = notif;

        let rawApp = notif.appName || notif.desktopEntry || "Sistema";
        root.currentAppName = sanitizeText(rawApp);
        root.currentIcon = notif.appIcon || notif.desktopEntry || "";
        root.currentSummary = sanitizeText(notif.summary);
        root.currentBody = sanitizeText(notif.body);
        root.currentTime = Qt.formatDateTime(new Date(), "hh:mm");

        // Detección de reproducción en Spotify
        let isSpot = (rawApp.toLowerCase().indexOf("spotify") !== -1 ||
                      (notif.desktopEntry && notif.desktopEntry.toLowerCase().indexOf("spotify") !== -1));
        root.isSpotifyTrack = isSpot;

        // Clasificación de marca y agente
        let classification = classifyNotification(rawApp, notif.summary, notif.body, notif.desktopEntry);
        root.isAgentOrTerminal = classification.isAgentOrTerminal;
        root.agentName = classification.agentName;
        root.asciiIcon = classification.asciiIcon;
        root.gradientColor = classification.color;

        if (isSpot) {
            // Formateo exclusivo para Spotify: "solo muestre album- artista"
            let album = (MediaService.isSpotify && MediaService.rawAlbum) ? sanitizeText(MediaService.rawAlbum) : "";
            let artist = (MediaService.isSpotify && MediaService.rawArtist) ? sanitizeText(MediaService.rawArtist) : sanitizeText(notif.summary);

            if (!album && notif.body) {
                album = sanitizeText(notif.summary);
                artist = sanitizeText(notif.body);
            }

            if (album && artist && album.toLowerCase() !== artist.toLowerCase()) {
                root.formattedText = album + " - " + artist;
            } else if (album) {
                root.formattedText = album;
            } else if (artist) {
                root.formattedText = artist;
            } else {
                root.formattedText = "Spotify";
            }

            let art = (MediaService.isSpotify && MediaService.artUrl) ? MediaService.artUrl : "";
            if (art) {
                root.extractAlbumPalette(art);
            }
        } else {
            let cleanSummary = root.currentSummary;
            if (cleanSummary.toLowerCase() === root.currentAppName.toLowerCase()) {
                cleanSummary = "";
            }

            let rawMsg = "";
            if (cleanSummary !== "" && root.currentBody !== "") {
                rawMsg = cleanSummary + " - " + root.currentBody;
            } else if (cleanSummary !== "") {
                rawMsg = cleanSummary;
            } else if (root.currentBody !== "") {
                rawMsg = root.currentBody;
            } else {
                rawMsg = "Notificación";
            }

            const maxLen = 65;
            if (rawMsg.length > maxLen) {
                rawMsg = rawMsg.substring(0, maxLen).trim() + "…";
            }

            root.formattedText = root.currentAppName + ":" + rawMsg + " " + root.currentTime;
        }

        root.hasActiveNotification = true;

        dismissTimer.stop();
        let timeout = (notif.expireTimeout && notif.expireTimeout > 0)
                      ? Math.min(Math.max(notif.expireTimeout, 2000), 8000)
                      : 4000;
        dismissTimer.interval = timeout;
        dismissTimer.start();
    }

    function dismissCurrent(): void {
        root.hasActiveNotification = false;
        root.isSpotifyTrack = false;
        root.isAgentOrTerminal = false;
        root.agentName = "";
        root.asciiIcon = "";
        root.gradientColor = "#7f99cc";
        dismissTimer.stop();
        if (root.activeNotif) {
            try { root.activeNotif.dismiss(); } catch (e) {}
            root.activeNotif = null;
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        actionsSupported: false
        imageSupported: true

        onNotification: (notif) => {
            root.handleNotification(notif);
        }
    }
}
