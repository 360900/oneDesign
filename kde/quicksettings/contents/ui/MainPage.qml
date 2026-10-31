import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import "../code/tiles.js" as Tiles

ColumnLayout {
    spacing: Kirigami.Units.largeSpacing * 1.5

    readonly property var audio: root.audio
    readonly property var net: root.net
    readonly property var bt: root.bt
    readonly property var power: root.power
    readonly property var display: root.display
    readonly property var notify: root.notify
    readonly property var session: root.session
    readonly property var keyboard: root.keyboard
    readonly property var devices: root.devices
    readonly property var cfg: root.cfg
    readonly property var tileIds: Tiles.visible(cfg.tileOrder, cfg.hiddenTiles, root.custom ? root.custom.tiles : [])

    KCoreAddons.KUser { id: user }

    // Header: user, power state, actions
    RowLayout {
        visible: cfg.showHeader
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Item {
            visible: cfg.showAvatar
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
            Layout.preferredHeight: Layout.preferredWidth

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: width / 2
                color: Kirigami.Theme.highlightColor
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: (user.fullName || user.loginName).charAt(0).toUpperCase()
                    color: Kirigami.Theme.highlightedTextColor
                    font.weight: Font.Bold
                }
            }
            Kirigami.ShadowedImage {
                id: face
                anchors.fill: parent
                source: user.faceIconUrl
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                radius: width / 2
                color: "transparent"
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: user.fullName || user.loginName
                color: Kirigami.Theme.textColor
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (!power) return "";
                    if (power.hasBattery) return power.batteryText;
                    const parts = [i18n("On AC power")];
                    if (power.profilesAvailable) parts.push(power.profileName(power.profile));
                    return parts.join(" · ");
                }
                color: Kirigami.Theme.textColor
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }

        IconBtn {
            visible: cfg.showSettingsButton
            icon: "emblem-system-symbolic"
            onClicked: root.openKcm("kcm_landingpage")
        }
        IconBtn {
            visible: cfg.showLockButton && !!session && session.canLock
            icon: "system-lock-screen-symbolic"
            onClicked: { root.expanded = false; session.lock(); }
        }
        IconBtn {
            visible: cfg.showPowerButton && !!session
            icon: "system-shutdown-symbolic"
            onClicked: root.page = "Power"
        }
    }

    Rectangle {
        visible: cfg.showCamera && !!root.camera && root.camera.inUse
        Layout.fillWidth: true
        implicitHeight: camRow.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.16)
        RowLayout {
            id: camRow
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing * 1.5
            anchors.rightMargin: Kirigami.Units.largeSpacing * 1.5
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "camera-web-symbolic"
                isMask: true
                color: Kirigami.Theme.neutralTextColor
            }
            Text {
                Layout.fillWidth: true
                text: root.camera && root.camera.count > 1 ? i18n("%1 cameras are in use", root.camera.count) : i18n("Camera is in use")
                color: Kirigami.Theme.textColor
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    SliderRow {
        visible: cfg.showVolume && !!audio && audio.available
        icon: audio ? audio.icon : ""
        iconClickable: true
        value: audio ? audio.percent : 0
        hasMore: true
        onMoved: v => audio.setPercent(v)
        onIconClicked: audio.toggleMute()
        onMore: root.page = "Audio"
    }

    Repeater {
        model: cfg.showBrightness && display && display.brightnessAvailable ? display.displays : []
        SliderRow {
            icon: "display-brightness-symbolic"
            value: model.brightness
            to: model.maxBrightness
            onMoved: v => display.setBrightness(model.displayName, v)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        columns: Math.max(1, Math.min(3, cfg.columns))
        columnSpacing: Kirigami.Units.largeSpacing + 2
        rowSpacing: Kirigami.Units.largeSpacing + 2
        uniformCellWidths: true

        Repeater {
            model: tileIds
            Loader {
                required property string modelData
                readonly property string tileId: modelData
                Layout.fillWidth: true
                visible: !!item && item.shown
                sourceComponent: tileId.startsWith("c-") ? customTile : (builtins[tileId] || null)
            }
        }
    }

    readonly property var builtins: ({
        network: networkTile, bluetooth: bluetoothTile, power: powerTile, nightlight: nightTile,
        darkmode: darkTile, dnd: dndTile, keyboard: keyboardTile
    })

    Component {
        id: networkTile
        Tile {
            readonly property bool wifi: !!net && net.wifiAvailable
            shown: !!net
            icon: !net ? "" : wifi ? net.wifiIcon : net.icon
            label: wifi ? i18n("Wi-Fi") : i18n("Wired")
            sub: !net ? "" : wifi ? (!net.wifiOn ? i18n("Off") : net.wifiConnected ? net.active.name : i18n("Not connected"))
                                  : (net.wiredConnected ? i18n("Connected") : i18n("Disconnected"))
            on: !!net && (wifi ? net.wifiOn : net.wiredConnected)
            hasMore: wifi
            onToggled: wifi ? net.setWifi(!net.wifiOn) : root.openKcm("kcm_networkmanagement")
            onMore: root.page = "Wifi"
        }
    }
    Component {
        id: bluetoothTile
        Tile {
            shown: !!bt && bt.available
            icon: bt ? bt.icon : ""
            label: i18n("Bluetooth")
            sub: !bt ? "" : !bt.on ? i18n("Off") : bt.summary
            on: !!bt && bt.on
            hasMore: true
            onToggled: bt.setOn(!bt.on)
            onMore: root.page = "Bluetooth"
        }
    }
    Component {
        id: powerTile
        Tile {
            shown: !!power && power.profilesAvailable
            icon: power ? power.profileIcon : ""
            label: i18n("Power Mode")
            sub: power ? power.profileName(power.profile) : ""
            on: !!power && power.profile !== "balanced"
            hasMore: true
            onToggled: root.page = "Profiles"
            onMore: root.page = "Profiles"
        }
    }
    Component {
        id: nightTile
        Tile {
            shown: !!display && display.nightLightAvailable
            icon: "night-light-symbolic"
            label: i18n("Night Light")
            sub: !display ? "" : display.nightLightOn ? i18n("On") : display.nightLightEnabled ? i18n("Paused") : i18n("Off")
            on: !!display && display.nightLightOn
            onToggled: display.nightLightEnabled ? display.toggleNightLight() : root.openKcm("kcm_nightlight")
        }
    }
    Component {
        id: darkTile
        Tile {
            shown: !!display
            icon: "weather-clear-night-symbolic"
            label: i18n("Dark Style")
            on: !!display && display.darkMode
            onToggled: display.setDarkMode(!display.darkMode)
        }
    }
    Component {
        id: dndTile
        Tile {
            shown: !!notify
            icon: "notifications-disabled-symbolic"
            label: i18n("Do Not Disturb")
            on: !!notify && notify.dnd
            onToggled: notify.setDnd(!notify.dnd)
        }
    }
    Component {
        id: keyboardTile
        Tile {
            shown: !!keyboard && keyboard.multiple
            icon: "input-keyboard-symbolic"
            label: i18n("Keyboard")
            sub: keyboard ? keyboard.longName : ""
            hasMore: true
            onToggled: keyboard.next()
            onMore: root.page = "Keyboard"
        }
    }
    Component {
        id: customTile
        Tile {
            readonly property string tid: parent ? parent.tileId : ""
            readonly property var def: root.custom && tid ? root.custom.tile(tid) : null
            readonly property bool toggle: root.custom ? root.custom.isToggle(def) : false
            shown: !!def
            icon: def ? (def.icon || "system-run-symbolic") : ""
            label: def ? def.label : ""
            sub: !toggle ? "" : on ? i18n("On") : i18n("Off")
            on: toggle && !!root.custom.states[tid]
            onToggled: root.custom.activate(tid)
        }
    }

    ColumnLayout {
        visible: cfg.showDevices && !!devices && devices.any
        Layout.fillWidth: true
        spacing: 0
        Text {
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            text: i18n("Devices")
            color: Kirigami.Theme.textColor
            opacity: 0.6
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        Repeater {
            model: devices ? devices.items : []
            DeviceRow { required property var modelData; device: modelData }
        }
    }
}
