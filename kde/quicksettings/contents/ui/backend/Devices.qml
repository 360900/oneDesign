import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Removable storage via lsblk + udisksctl (same operations the device notifier offers).
Item {
    id: dev

    property var items: []
    property string busy: ""
    readonly property bool any: items.length > 0

    readonly property string listCmd: "lsblk -J -b -o PATH,LABEL,SIZE,MOUNTPOINT,RM,HOTPLUG,TYPE,FSTYPE,MODEL,TRAN"

    function human(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0, v = Number(bytes);
        while (v >= 1000 && i < units.length - 1) { v /= 1000; i++; }
        return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    function parse(text) {
        let tree;
        try { tree = JSON.parse(text).blockdevices || []; } catch (e) { return; }
        const out = [];
        for (const disk of tree) {
            const removable = disk.rm || disk.tran === "usb" || disk.tran === "mmc" || disk.type === "rom";
            if (!removable || disk.type === "loop") continue;
            const parts = (disk.children || []).filter(p => p.fstype && p.fstype !== "swap");
            if (disk.fstype) parts.unshift(disk);
            for (const p of parts) {
                if (p.mountpoint === "/" || p.mountpoint === "[SWAP]") continue;
                out.push({
                    path: p.path,
                    disk: disk.path,
                    name: p.label || disk.model || i18n("%1 Drive", human(p.size)),
                    size: human(p.size),
                    mounted: p.mountpoint || "",
                    icon: disk.type === "rom" ? "media-optical-symbolic" : "media-removable-symbolic",
                });
            }
        }
        items = out;
    }

    function run(cmd, path) {
        busy = path;
        exec.connectSource(cmd);
    }
    function open(item) {
        run("sh -c 'm=$(lsblk -no MOUNTPOINT \"$1\"); [ -n \"$m\" ] || udisksctl mount -b \"$1\" >/dev/null && xdg-open \"$(lsblk -no MOUNTPOINT \"$1\")\"' _ " + item.path, item.path);
    }
    function eject(item) {
        // Unmount every mounted partition of the disk, then power it off.
        run("sh -c 'for p in $(lsblk -nlo PATH,MOUNTPOINT \"$1\" | awk \"NF>1{print \\$1}\"); do udisksctl unmount -b \"$p\" >/dev/null || exit 1; done; udisksctl power-off -b \"$1\" >/dev/null 2>&1 || true' _ " + item.disk, item.path);
    }
    function refresh() { exec.connectSource(listCmd); }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source === dev.listCmd) {
                dev.parse(data["stdout"]);
            } else {
                dev.busy = "";
                dev.refresh();
            }
        }
    }

    Timer {
        interval: root.expanded ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dev.refresh()
    }
}
