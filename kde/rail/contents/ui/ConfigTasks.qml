import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showPinned: pinned.checked
    property alias cfg_separateLaunchers: separate.checked
    property alias cfg_onlyCurrentDesktop: desk.checked
    property alias cfg_onlyCurrentScreen: screen.checked
    property alias cfg_onlyCurrentActivity: activity.checked
    property alias cfg_onlyMinimized: minimized.checked
    property int cfg_grouping
    property int cfg_sorting
    property int cfg_middleClick
    property alias cfg_wheelSwitchTasks: wheel.checked
    property alias cfg_showToolTips: tips.checked
    property alias cfg_showRunningIndicator: indicator.checked
    property alias cfg_highlightAttention: attention.checked
    property bool cfg_showPinnedDefault
    property bool cfg_separateLaunchersDefault
    property bool cfg_onlyCurrentDesktopDefault
    property bool cfg_onlyCurrentScreenDefault
    property bool cfg_onlyCurrentActivityDefault
    property bool cfg_onlyMinimizedDefault
    property int cfg_groupingDefault
    property int cfg_sortingDefault
    property int cfg_middleClickDefault
    property bool cfg_wheelSwitchTasksDefault
    property bool cfg_showToolTipsDefault
    property bool cfg_showRunningIndicatorDefault
    property bool cfg_highlightAttentionDefault

    Kirigami.FormLayout {
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Show") }
        QQC.CheckBox { id: pinned; text: i18n("Show pinned apps that are not running") }
        QQC.CheckBox { id: separate; text: i18n("Keep pinned apps separate from running ones") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Show only apps") }
        QQC.CheckBox { id: desk; text: i18n("from the current workspace") }
        QQC.CheckBox { id: screen; text: i18n("from the current screen") }
        QQC.CheckBox { id: activity; text: i18n("from the current activity") }
        QQC.CheckBox { id: minimized; text: i18n("that are minimized") }

        Item { Kirigami.FormData.isSection: true }
        QQC.ComboBox {
            Kirigami.FormData.label: i18n("Group:")
            model: [i18n("Do not group"), i18n("By program name")]
            currentIndex: cfg_grouping
            onActivated: index => cfg_grouping = index
        }
        QQC.ComboBox {
            Kirigami.FormData.label: i18n("Sort:")
            model: [i18n("Manually"), i18n("Alphabetically"), i18n("By workspace"), i18n("By activity")]
            currentIndex: cfg_sorting
            onActivated: index => cfg_sorting = index
        }
        QQC.ComboBox {
            Kirigami.FormData.label: i18n("On middle-click:")
            model: [i18n("Does nothing"), i18n("Closes the window or group"), i18n("Opens a new window"),
                    i18n("Minimizes or restores"), i18n("Brings it to the current workspace")]
            currentIndex: cfg_middleClick
            onActivated: index => cfg_middleClick = index
        }
        QQC.CheckBox { id: wheel; Kirigami.FormData.label: i18n("Mouse wheel:"); text: i18n("Cycles through running apps") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Appearance") }
        QQC.CheckBox { id: tips; text: i18n("Show tooltips") }
        QQC.CheckBox { id: indicator; text: i18n("Mark running apps on the screen edge") }
        QQC.CheckBox { id: attention; text: i18n("Highlight apps that ask for attention") }
    }
}
