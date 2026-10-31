import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigBase {
    id: page

    component Check: QQC.CheckBox {
        required property string key
        checked: page["cfg_" + key]
        onToggled: page["cfg_" + key] = checked
    }

    Kirigami.FormLayout {
        Check { key: "panelNetwork"; Kirigami.FormData.label: i18n("Panel icons:"); text: i18n("Network") }
        Check { key: "panelBluetooth"; text: i18n("Bluetooth (when a device is connected)") }
        Check { key: "panelVolume"; text: i18n("Volume") }
        Check { key: "panelPower"; text: i18n("Battery or power mode") }
        Check { key: "panelDnd"; text: i18n("Do Not Disturb (when on)") }
        Check { key: "panelDevices"; text: i18n("Removable devices (when plugged in)") }
        Check { key: "panelKeyboard"; text: i18n("Keyboard layout (with several layouts)") }
        Check { key: "panelCamera"; text: i18n("Camera in use") }

        Item { Kirigami.FormData.isSection: true }

        Check { key: "showHeader"; Kirigami.FormData.label: i18n("Header:"); text: i18n("Show header") }
        Check { key: "showAvatar"; text: i18n("User picture and name"); enabled: page.cfg_showHeader; Layout.leftMargin: Kirigami.Units.gridUnit }
        Check { key: "showSettingsButton"; text: i18n("Settings button"); enabled: page.cfg_showHeader; Layout.leftMargin: Kirigami.Units.gridUnit }
        Check { key: "showLockButton"; text: i18n("Lock button"); enabled: page.cfg_showHeader; Layout.leftMargin: Kirigami.Units.gridUnit }
        Check { key: "showPowerButton"; text: i18n("Power button"); enabled: page.cfg_showHeader; Layout.leftMargin: Kirigami.Units.gridUnit }

        Item { Kirigami.FormData.isSection: true }

        Check { key: "showVolume"; Kirigami.FormData.label: i18n("Sections:"); text: i18n("Volume slider") }
        Check { key: "showBrightness"; text: i18n("Brightness sliders") }
        Check { key: "showCamera"; text: i18n("Camera in use banner") }
        Check { key: "showDevices"; text: i18n("Removable devices") }

        Item { Kirigami.FormData.isSection: true }

        QQC.ComboBox {
            Kirigami.FormData.label: i18n("Tile columns:")
            model: ["1", "2", "3"]
            currentIndex: page.cfg_columns - 1
            onActivated: index => page.cfg_columns = index + 1
        }
        Check { key: "compactTiles"; text: i18n("Compact tiles (no status line)") }
    }
}
