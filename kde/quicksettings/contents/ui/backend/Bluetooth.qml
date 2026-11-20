import QtQuick
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.bluetooth as PlasmaBt

Item {
    id: root
    // The adapter disappears while the radio is blocked and takes a moment to
    // come back after unblocking; keep the tile in place across that gap.
    property bool awaitingAdapter: false
    readonly property bool available: BluezQt.Manager.adapters.length > 0
        || BluezQt.Manager.bluetoothBlocked || awaitingAdapter
    readonly property bool on: BluezQt.Manager.bluetoothOperational
    readonly property var connected: BluezQt.Manager.connectedDevices
    readonly property string icon: !on ? "bluetooth-disabled-symbolic"
        : connected.length > 0 ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
    readonly property string summary: connected.length === 1 ? connected[0].name
        : connected.length > 1 ? i18np("%1 device", "%1 devices", connected.length) : ""
    readonly property alias model: devices

    property bool wantOn: false

    function setOn(enable) {
        wantOn = enable;
        awaitingAdapter = enable && BluezQt.Manager.adapters.length === 0;
        BluezQt.Manager.bluetoothBlocked = !enable;
        for (const a of BluezQt.Manager.adapters) a.powered = enable;
    }
    function toggleDevice(device, ubi, isConnected) {
        if (isConnected) {
            PlasmaBt.SharedDevicesStateProxyModel.registerDisconnectingCallForDeviceUbi(device.disconnectFromDevice(), ubi);
        } else {
            PlasmaBt.SharedDevicesStateProxyModel.registerConnectingCallForDeviceUbi(device.connectToDevice(), ubi);
        }
    }

    // Unblocking brings the adapter back unpowered; power it once it shows up.
    Connections {
        target: BluezQt.Manager
        function onAdapterAdded(adapter) {
            root.awaitingAdapter = false;
            if (root.wantOn) adapter.powered = true;
        }
        function onBluetoothOperationalChanged(operational) {
            if (operational) root.awaitingAdapter = false;
        }
    }

    PlasmaBt.DevicesProxyModel {
        id: devices
        hideBlockedDevices: true
        Component.onCompleted: sourceModel = PlasmaBt.SharedDevicesStateProxyModel
    }
}
