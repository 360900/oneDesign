import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.networkmanagement as PlasmaNM

ColumnLayout {
    id: page
    spacing: Kirigami.Units.smallSpacing

    readonly property var net: root.net
    property string passwordFor: ""

    Component.onCompleted: net.scan()

    Timer {
        interval: 10000
        repeat: true
        running: net.wifiOn
        onTriggered: net.scan()
    }

    PageHeader {
        title: i18n("Wi-Fi")
        hasToggle: true
        on: net.wifiOn
        onToggled: net.setWifi(!net.wifiOn)
    }

    Text {
        visible: !net.wifiOn
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        text: i18n("Wi-Fi is turned off")
        color: Kirigami.Theme.textColor
        opacity: 0.6
        horizontalAlignment: Text.AlignHCenter
    }

    ListView {
        id: list
        visible: net.wifiOn
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 16)
        clip: true
        model: net.model
        boundsBehavior: Flickable.StopAtBounds

        delegate: ColumnLayout {
            id: entry
            required property var model
            readonly property bool wifi: model.Type === PlasmaNM.Enums.Wireless
            readonly property bool activated: model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property bool activating: model.ConnectionState === PlasmaNM.Enums.Activating
            readonly property bool staticPassword: [PlasmaNM.Enums.StaticWep, PlasmaNM.Enums.WpaPsk,
                PlasmaNM.Enums.Wpa2Psk, PlasmaNM.Enums.SAE].indexOf(model.SecurityType) >= 0
            readonly property bool askPassword: !model.Uuid && staticPassword

            width: ListView.view.width
            visible: wifi
            height: wifi ? implicitHeight : 0
            spacing: 0

            function connect(password) {
                const h = net.handler;
                if (activated) {
                    h.deactivateConnection(model.ConnectionPath, model.DevicePath);
                } else if (model.Uuid) {
                    h.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath);
                } else if (askPassword && password === undefined) {
                    page.passwordFor = page.passwordFor === model.ItemUniqueName ? "" : model.ItemUniqueName;
                    return;
                } else if (password !== undefined) {
                    h.addAndActivateConnection(model.DevicePath, model.SpecificPath, password);
                } else {
                    h.addAndActivateConnection(model.DevicePath, model.SpecificPath);
                }
                page.passwordFor = "";
            }

            ListRow {
                icon: {
                    const n = entry.model.ConnectionIcon || "network-wireless-signal-none";
                    return n.endsWith("-symbolic") ? n : n + "-symbolic";
                }
                label: entry.model.ItemUniqueName
                sub: entry.activated ? i18n("Connected")
                    : entry.activating ? i18n("Connecting…")
                    : entry.model.Uuid ? i18n("Saved")
                    : entry.model.SecurityType === PlasmaNM.Enums.NoneSecurity ? i18n("Open") : i18n("Secured")
                checked: entry.activated
                busy: entry.activating
                onClicked: entry.connect()
            }

            RowLayout {
                visible: page.passwordFor === entry.model.ItemUniqueName
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing
                PC3.TextField {
                    id: pass
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: i18n("Password")
                    onVisibleChanged: if (visible) forceActiveFocus()
                    onAccepted: if (text.length) entry.connect(text)
                }
                IconBtn {
                    icon: "go-next-symbolic"
                    on: pass.text.length >= 8
                    onClicked: if (pass.text.length) entry.connect(pass.text)
                }
            }
        }
    }

    ListRow {
        icon: "emblem-system-symbolic"
        label: i18n("Network Settings")
        onClicked: root.openKcm("kcm_networkmanagement")
    }
}
