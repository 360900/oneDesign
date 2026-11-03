import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showWorkspaces: showWs.checked
    property alias cfg_showWorkspaceNumbers: wsNums.checked
    property alias cfg_showAddWorkspace: addWs.checked
    property alias cfg_maxDesktops: maxDesks.value
    property alias cfg_showApps: showApps.checked
    property alias cfg_showSeparator: sep.checked
    property bool cfg_workspacesFirst
    property int cfg_hideMode
    property int cfg_hideModeDefault
    property alias cfg_tileSize: tile.value
    property alias cfg_iconSize: icon.value
    property alias cfg_appSpacing: spacing.value
    property alias cfg_fillWhenMaximized: fillMax.checked
    property bool cfg_showWorkspacesDefault
    property bool cfg_showWorkspaceNumbersDefault
    property bool cfg_showAddWorkspaceDefault
    property int cfg_maxDesktopsDefault
    property bool cfg_showAppsDefault
    property bool cfg_showSeparatorDefault
    property bool cfg_workspacesFirstDefault
    property int cfg_tileSizeDefault
    property int cfg_iconSizeDefault
    property int cfg_appSpacingDefault
    property bool cfg_fillWhenMaximizedDefault

    Kirigami.FormLayout {
        QQC.ComboBox {
            Kirigami.FormData.label: i18n("Order:")
            model: [i18n("Workspaces on top, apps below"), i18n("Apps on top, workspaces below")]
            currentIndex: cfg_workspacesFirst ? 0 : 1
            onActivated: index => cfg_workspacesFirst = index === 0
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Workspaces") }
        QQC.CheckBox { id: showWs; text: i18n("Show workspace thumbnails") }
        QQC.CheckBox { id: wsNums; text: i18n("Show workspace numbers"); enabled: showWs.checked }
        QQC.CheckBox { id: addWs; text: i18n("Show the add workspace button"); enabled: showWs.checked }
        QQC.SpinBox {
            id: maxDesks
            Kirigami.FormData.label: i18n("Most workspaces:")
            from: 1; to: 12
            enabled: showWs.checked && addWs.checked
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Apps") }
        QQC.CheckBox { id: showApps; text: i18n("Show apps") }
        QQC.CheckBox { id: sep; text: i18n("Show a separator between workspaces and apps") }
        QQC.SpinBox { id: tile; Kirigami.FormData.label: i18n("Tile size:"); from: 36; to: 52; enabled: showApps.checked }
        QQC.SpinBox { id: icon; Kirigami.FormData.label: i18n("Icon size:"); from: 20; to: 48; enabled: showApps.checked }
        QQC.SpinBox { id: spacing; Kirigami.FormData.label: i18n("Spacing:"); from: 0; to: 20; enabled: showApps.checked }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Panel") }
        QQC.ComboBox {
            Kirigami.FormData.label: i18n("Visibility:")
            model: [i18n("Always visible"), i18n("Auto-hide (expands on hover)"), i18n("Windows can cover it")]
            currentIndex: cfg_hideMode
            onActivated: index => cfg_hideMode = index
        }
        QQC.CheckBox { id: fillMax; text: i18n("Use the full screen height while a window is maximized") }
    }
}
