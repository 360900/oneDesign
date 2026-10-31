import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ListRow {
    id: row

    required property var device

    icon: device.icon
    label: device.name
    sub: device.mounted ? i18n("%1 · Mounted", device.size) : device.size
    busy: root.devices && root.devices.busy === device.path
    trailing: Kirigami.Units.gridUnit * 1.8
    onClicked: root.devices.open(device)

    IconBtn {
        anchors { right: parent.right; rightMargin: Kirigami.Units.smallSpacing; verticalCenter: parent.verticalCenter }
        visible: !row.busy
        size: Kirigami.Units.gridUnit * 1.8
        icon: "media-eject-symbolic"
        onClicked: root.devices.eject(row.device)
    }
}
