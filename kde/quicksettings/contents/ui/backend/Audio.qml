import QtQuick
import org.kde.plasma.private.volume

Item {
    readonly property var sink: PreferredDevice.sink
    readonly property bool available: !!sink && sink.name !== "auto_null"
    readonly property int percent: available ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) : 0
    readonly property bool muted: available ? sink.muted : true
    readonly property string icon: symbolic(AudioIcon.forVolume(percent, muted, ""))
    readonly property string deviceName: available ? sink.description : ""
    readonly property alias outputs: outputModel

    function symbolic(name) {
        return name.endsWith("-symbolic") ? name : name + "-symbolic";
    }
    function setPercent(p) {
        if (!available) return;
        sink.volume = Math.round(PulseAudio.NormalVolume * p / 100);
        if (p > 0 && sink.muted) sink.muted = false;
    }
    function toggleMute() {
        if (available) sink.muted = !sink.muted;
    }

    PulseObjectFilterModel {
        id: outputModel
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: SinkModel {}
    }
}
