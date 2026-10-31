import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    readonly property var icons: {
        const c = root.cfg;
        const list = [];
        if (c.panelDevices && root.devices && root.devices.any) list.push("media-removable-symbolic");
        if (c.panelNetwork && root.net) list.push(root.net.icon);
        if (c.panelBluetooth && root.bt && root.bt.available && root.bt.on && root.bt.connected.length > 0) list.push(root.bt.icon);
        if (c.panelVolume && root.audio && root.audio.available) list.push(root.audio.icon);
        if (c.panelPower && root.power && (root.power.hasBattery || root.power.profilesAvailable)) list.push(root.power.icon);
        if (c.panelDnd && root.notify && root.notify.dnd) list.push("notifications-disabled-symbolic");
        return list.length ? list : ["emblem-system-symbolic"];
    }

    Layout.minimumWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: root.expanded = !root.expanded
    onWheel: wheel => {
        if (!root.audio || !root.audio.available) return;
        const step = wheel.angleDelta.y > 0 ? 5 : -5;
        root.audio.setPercent(Math.max(0, Math.min(100, root.audio.percent + step)));
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Math.max(0, (parent.height - Kirigami.Units.gridUnit * 1.6) / 2)
        anchors.bottomMargin: anchors.topMargin
        radius: height / 2
        color: Kirigami.Theme.textColor
        opacity: root.expanded ? 0.14 : compact.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.mediumSpacing + 2

        // Privacy indicator, GNOME-style warm pill
        Rectangle {
            visible: root.cfg.panelCamera && !!root.camera && root.camera.inUse
            Layout.preferredWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.largeSpacing * 2
            Layout.preferredHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
            radius: height / 2
            color: Kirigami.Theme.neutralTextColor
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "camera-web-symbolic"
                isMask: true
                color: "white"
            }
        }
        Text {
            visible: root.cfg.panelKeyboard && !!root.keyboard && root.keyboard.multiple
            text: root.keyboard ? root.keyboard.shortName.toLowerCase() : ""
            color: Kirigami.Theme.textColor
            font.weight: Font.DemiBold
        }
        Repeater {
            model: compact.icons
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: modelData
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }
}
