import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kcmutils as KCMUtils

PlasmoidItem {
    id: root

    readonly property var audio: audioLoader.item
    readonly property var net: netLoader.item
    readonly property var bt: btLoader.item
    readonly property var power: powerLoader.item
    readonly property var display: displayLoader.item
    readonly property var notify: notifyLoader.item
    readonly property var session: sessionLoader.item
    readonly property var camera: cameraLoader.item
    readonly property var keyboard: keyboardLoader.item
    readonly property var devices: devicesLoader.item
    readonly property var custom: customLoader.item
    readonly property var cfg: Plasmoid.configuration

    property string page: ""

    function openKcm(name) {
        KCMUtils.KCMLauncher.openSystemSettings(name);
        root.expanded = false;
    }

    Plasmoid.icon: "emblem-system-symbolic"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: i18n("Quick Settings")
    toolTipSubText: {
        const parts = [];
        if (net && net.active) parts.push(net.active.name);
        if (audio && audio.available) parts.push(i18n("Volume %1%", audio.percent));
        if (power && power.hasBattery) parts.push(power.batteryText);
        if (keyboard && keyboard.multiple) parts.push(keyboard.longName);
        if (camera && camera.inUse) parts.push(i18n("Camera in use"));
        return parts.join("\n");
    }

    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactRep {}
    fullRepresentation: FullRep {}

    onExpandedChanged: if (!root.expanded) page = ""

    Item {
        visible: false
        Loader { id: audioLoader; source: "backend/Audio.qml" }
        Loader { id: netLoader; source: "backend/Network.qml" }
        Loader { id: btLoader; source: "backend/Bluetooth.qml" }
        Loader { id: powerLoader; source: "backend/Power.qml" }
        Loader { id: displayLoader; source: "backend/Display.qml" }
        Loader { id: notifyLoader; source: "backend/Notify.qml" }
        Loader { id: sessionLoader; source: "backend/Session.qml" }
        Loader { id: cameraLoader; source: "backend/Camera.qml" }
        Loader { id: keyboardLoader; source: "backend/Keyboard.qml" }
        Loader { id: devicesLoader; source: "backend/Devices.qml" }
        Loader {
            id: customLoader
            source: "backend/Custom.qml"
            onLoaded: {
                item.json = Qt.binding(() => root.cfg.customTiles);
                item.polling = Qt.binding(() => root.expanded);
            }
        }
    }
}
