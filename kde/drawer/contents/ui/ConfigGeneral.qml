import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_drawerWidth: width.value
    property alias cfg_iconSize: icon.value
    property alias cfg_showRunning: running.checked
    property alias cfg_showPinned: pinned.checked
    property bool cfg_runningFirst
    property alias cfg_groupApps: group.checked
    property alias cfg_showAllApps: allApps.checked
    property alias cfg_closeWhenUnfocused: closeUnfocused.checked
    property alias cfg_showUserRow: userRow.checked
    property alias cfg_showUserName: userName.checked
    property alias cfg_showSettingsButton: settings.checked
    property int cfg_drawerWidthDefault
    property int cfg_iconSizeDefault
    property bool cfg_showRunningDefault
    property bool cfg_showPinnedDefault
    property bool cfg_runningFirstDefault
    property bool cfg_groupAppsDefault
    property bool cfg_showAllAppsDefault
    property bool cfg_closeWhenUnfocusedDefault
    property bool cfg_showUserRowDefault
    property bool cfg_showUserNameDefault
    property bool cfg_showSettingsButtonDefault

    Kirigami.FormLayout {
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Drawer") }
        QQC.SpinBox { id: width; Kirigami.FormData.label: i18n("Width:"); from: 220; to: 440; stepSize: 8 }
        QQC.SpinBox { id: icon; Kirigami.FormData.label: i18n("Icon size:"); from: 20; to: 40 }
        QQC.CheckBox { id: closeUnfocused; text: i18n("Close when it loses focus") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Apps") }
        QQC.CheckBox { id: running; text: i18n("Show running apps") }
        QQC.CheckBox { id: pinned; text: i18n("Show pinned apps") }
        QQC.ComboBox {
            Kirigami.FormData.label: i18n("Order:")
            enabled: running.checked && pinned.checked
            model: [i18n("Running first"), i18n("Pinned first")]
            currentIndex: cfg_runningFirst ? 0 : 1
            onActivated: index => cfg_runningFirst = index === 0
        }
        QQC.CheckBox { id: group; text: i18n("Group windows of the same app") }
        QQC.CheckBox { id: allApps; text: i18n("Show all apps, by category") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Search") }
        QQC.Button {
            text: i18n("Configure Search…")
            icon.name: "settings-configure"
            onClicked: KCM.KCMLauncher.openSystemSettings("kcm_plasmasearch")
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Bottom row") }
        QQC.CheckBox { id: userRow; text: i18n("Show the bottom row") }
        QQC.CheckBox { id: userName; text: i18n("Show your name"); enabled: userRow.checked }
        QQC.CheckBox { id: settings; text: i18n("Show the settings button"); enabled: userRow.checked }
    }
}
