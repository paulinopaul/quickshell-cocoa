pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

QtObject {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Output Audio
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0.0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // Input Audio (Microphone)
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0.0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : true

    function setVolume(v: real): void {
        if (sink && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0.0, Math.min(1.5, v));
        }
    }

    function stepVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function toggleMicMute(): void {
        if (source && source.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }
}
