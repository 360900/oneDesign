import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Removable storage from Solid, the same sources and mount operations as KDE's device notifier.
// Updates come as devices appear, mount and go; nothing is polled.
Item {
    id: dev

    property string busy: ""          // udi of the volume being mounted or unmounted
    property string openWhenReady: "" // udi to open once its mount finishes
    readonly property bool any: items.length > 0
    readonly property var items: {
        const out = [];
        for (const udi of hotplug.sources) {
            const d = solid.data[udi];
            if (!d || (!d.Removable && !d.Hotpluggable) || d["File Path"] === "/") continue;
            if ((d["Device Types"] || []).indexOf("Storage Access") < 0) continue;
            out.push({
                path: udi,
                disk: d["Parent UDI"] || udi,
                name: d.Label || d.Description || (hotplug.data[udi] || {}).text || i18n("%1 Drive", human(d.Size)),
                size: human(d.Size),
                mounted: d.Accessible ? d["File Path"] || "" : "",
                icon: (d["Device Types"] || []).indexOf("OpticalDisc") >= 0 ? "media-optical-symbolic" : "media-removable-symbolic",
            });
        }
        return out;
    }

    function human(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0, v = Number(bytes) || 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1000; i++; }
        return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    function operate(udi, name) {
        const service = solid.serviceForSource(udi);
        const job = service.startOperationCall(service.operationDescription(name));
        busy = udi;
        job.finished.connect(() => { if (dev.busy === udi) dev.busy = ""; });
    }
    function open(item) {
        if (item.mounted) {
            Qt.openUrlExternally("file://" + item.mounted);
            return;
        }
        openWhenReady = item.path;
        operate(item.path, "mount");
    }
    // Unmount every mounted volume of the drive (optical discs are ejected)
    function eject(item) {
        const vols = items.filter(v => v.disk === item.disk && (v.mounted || v.icon === "media-optical-symbolic"));
        (vols.length ? vols : [item]).forEach(v => operate(v.path, "unmount"));
    }

    P5Support.DataSource {
        id: hotplug
        engine: "hotplug"
        connectedSources: sources
        onSourceAdded: source => connectSource(source)
    }
    P5Support.DataSource {
        id: solid
        engine: "soliddevice"
        connectedSources: hotplug.sources
        onDataChanged: {
            const d = data[dev.openWhenReady];
            if (d && d.Accessible && d["File Path"]) {
                Qt.openUrlExternally("file://" + d["File Path"]);
                dev.openWhenReady = "";
            }
        }
    }
}
