import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

Item {
    id: net

    readonly property bool wifiAvailable: devices.wirelessDeviceAvailable
    readonly property bool wiredAvailable: devices.wiredDeviceAvailable
    readonly property bool wifiOn: enabled.wirelessEnabled
    readonly property bool wifiHw: enabled.wirelessHwEnabled
    readonly property bool scanning: handler.scanning
    readonly property bool connecting: connectionIcon.connecting
    readonly property string icon: connectionIcon.connectionIcon.endsWith("-symbolic")
        ? connectionIcon.connectionIcon : connectionIcon.connectionIcon + "-symbolic"
    readonly property alias model: proxy
    readonly property alias handler: handler
    property int rev: 0

    // Primary active connection: prefer Wi-Fi, then wired
    readonly property var active: {
        void instances.count;
        void net.rev;
        let found = null;
        for (let i = 0; i < instances.count; i++) {
            const o = instances.objectAt(i);
            if (!o || o.state !== PlasmaNM.Enums.Activated) continue;
            if (o.type === PlasmaNM.Enums.Wireless) return o;
            if (o.type === PlasmaNM.Enums.Wired && !found) found = o;
        }
        return found;
    }
    readonly property bool wifiConnected: !!active && active.type === PlasmaNM.Enums.Wireless
    readonly property bool wiredConnected: !!active && active.type === PlasmaNM.Enums.Wired

    readonly property string wifiIcon: !wifiOn ? "network-wireless-disabled-symbolic"
        : !wifiConnected ? "network-wireless-signal-none-symbolic"
        : "network-wireless-signal-" + (active.strength >= 80 ? "excellent" : active.strength >= 55 ? "good"
            : active.strength >= 30 ? "ok" : active.strength > 5 ? "weak" : "none") + "-symbolic"

    function setWifi(on) {
        handler.enableWireless(on);
    }
    function scan() {
        if (wifiOn) handler.requestScan();
    }

    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.AvailableDevices { id: devices }
    PlasmaNM.NetworkStatus { id: status }
    PlasmaNM.ConnectionIcon { id: connectionIcon; connectivity: status.connectivity }
    PlasmaNM.Handler { id: handler }
    PlasmaNM.AppletProxyModel {
        id: proxy
        sourceModel: PlasmaNM.NetworkModel {}
    }

    Instantiator {
        id: instances
        model: proxy
        delegate: QtObject {
            readonly property int state: model.ConnectionState
            readonly property int type: model.Type
            readonly property string name: model.ItemUniqueName
            readonly property int strength: model.Signal || 0
            onStateChanged: net.rev++
            onNameChanged: net.rev++
        }
    }
}
