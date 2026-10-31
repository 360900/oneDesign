import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    readonly property var bt: root.bt

    PageHeader {
        title: i18n("Bluetooth")
        hasToggle: true
        on: bt.on
        onToggled: bt.setOn(!bt.on)
    }

    Text {
        visible: !bt.on || list.count === 0
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        text: !bt.on ? i18n("Bluetooth is turned off") : i18n("No paired devices")
        color: Kirigami.Theme.textColor
        opacity: 0.6
        horizontalAlignment: Text.AlignHCenter
    }

    ListView {
        id: list
        visible: bt.on
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 16)
        clip: true
        model: bt.model
        boundsBehavior: Flickable.StopAtBounds

        delegate: ListRow {
            required property var model
            width: ListView.view.width
            icon: (model.Icon || "bluetooth") + "-symbolic"
            label: model.DeviceFullName || model.Name
            sub: model.Connecting ? i18n("Connecting…")
                : model.Disconnecting ? i18n("Disconnecting…")
                : model.Connected ? (model.Battery ? i18n("Connected · %1%", model.Battery.percentage) : i18n("Connected"))
                : model.Paired ? i18n("Paired") : ""
            checked: model.Connected
            busy: model.Connecting || model.Disconnecting
            onClicked: bt.toggleDevice(model.Device, model.Ubi, model.Connected)
        }
    }

    ListRow {
        icon: "emblem-system-symbolic"
        label: i18n("Bluetooth Settings")
        onClicked: root.openKcm("kcm_bluetooth")
    }
}
