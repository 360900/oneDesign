import QtQuick
import org.kde.kcmutils as KCM

// Both config pages declare every key so Plasma can hand all values to either page.
KCM.SimpleKCM {
    property var cfg_tileOrder: []
    property var cfg_hiddenTiles: []
    property string cfg_customTiles: "[]"
    property int cfg_columns: 2
    property bool cfg_compactTiles: false

    property bool cfg_showHeader: true
    property bool cfg_showAvatar: true
    property bool cfg_showSettingsButton: true
    property bool cfg_showLockButton: true
    property bool cfg_showPowerButton: true

    property bool cfg_showVolume: true
    property bool cfg_showBrightness: true
    property bool cfg_showCamera: true
    property bool cfg_showDevices: true

    property bool cfg_panelCamera: true
    property bool cfg_panelKeyboard: true
    property bool cfg_panelDevices: true
    property bool cfg_panelNetwork: true
    property bool cfg_panelBluetooth: true
    property bool cfg_panelVolume: true
    property bool cfg_panelPower: true
    property bool cfg_panelDnd: true
}
