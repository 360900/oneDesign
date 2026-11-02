import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

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

    // On a vertical panel (the rail) the icons stack instead of sitting in a row
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        || Plasmoid.location === PlasmaCore.Types.LeftEdge || Plasmoid.location === PlasmaCore.Types.RightEdge

    Layout.minimumWidth: vertical ? 0 : row.implicitWidth + Kirigami.Units.largeSpacing * 2
    Layout.preferredWidth: vertical ? 0 : Layout.minimumWidth
    Layout.minimumHeight: vertical ? col.implicitHeight + Kirigami.Units.largeSpacing * 2 : 0
    Layout.preferredHeight: vertical ? Layout.minimumHeight : -1
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: root.expanded = !root.expanded
    onWheel: wheel => {
        if (!root.audio || !root.audio.available) return;
        const step = wheel.angleDelta.y > 0 ? 5 : -5;
        root.audio.setPercent(Math.max(0, Math.min(100, root.audio.percent + step)));
    }

    readonly property bool dark: Kirigami.Theme.textColor.hsvValue > 0.5
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color hoverFill: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.2, 0.28, 0.4, 0.2)

    // One highlight for every control on the rail: same shape, white over glass; pressed only changes the color
    Rectangle {
        anchors.centerIn: parent
        width: compact.vertical ? 44 : parent.width
        height: compact.vertical ? Math.min(parent.height, col.implicitHeight + 16) : Math.min(parent.height, Kirigami.Units.gridUnit * 1.6)
        radius: compact.vertical ? 12 : height / 2
        color: root.expanded || compact.pressed ? Qt.tint(compact.hoverFill, Qt.rgba(compact.accent.r, compact.accent.g, compact.accent.b, compact.dark ? 0.45 : 0.30))
             : compact.containsMouse ? compact.hoverFill
             : Qt.rgba(compact.hoverFill.r, compact.hoverFill.g, compact.hoverFill.b, 0) // same hue, so the fade does not pass through grey
        border.width: compact.containsMouse || root.expanded || compact.pressed ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, compact.dark ? 0.12 : 0.6)
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    RowLayout {
        id: row
        visible: !compact.vertical
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

    ColumnLayout {
        id: col
        visible: compact.vertical
        anchors.centerIn: parent
        spacing: compact.icons.length > 3 ? Kirigami.Units.smallSpacing + 2 : Kirigami.Units.mediumSpacing + 4
        Repeater {
            model: compact.vertical ? compact.icons : []
            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: modelData
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }
}
